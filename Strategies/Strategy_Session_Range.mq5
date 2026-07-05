//+------------------------------------------------------------------+
//|                               Strategy_Session_Range.mq5         |
//|                                                                  |
//|  London Breakout / Asian-session range engine for MT5.            |
//|  v1 implements MODE_BREAKOUT only. MODE_FADE is reserved and      |
//|  explicitly fails closed until Asian_Session_Mean_Reversion is     |
//|  implemented.                                                     |
//|                                                                  |
//|  Time policy: strategy windows are defined conceptually in London  |
//|  time, but all inputs are server time. Defaults assume EET/EEST    |
//|  broker time: server 02:00-10:00 ~= London 00:00-08:00. DST        |
//|  mismatch weeks may be off by one hour in v1. The EA does not use  |
//|  TimeGMT because Strategy Tester GMT conversion is broker-dependent.|
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_SESSION_RANGE_MODE
  {
   MODE_BREAKOUT = 0, // London breakout
   MODE_FADE     = 1  // Reserved for Asian-session mean reversion
  };

enum ENUM_SESSION_SL_MODE
  {
   RANGE_OPPOSITE = 0, // Stop near the opposite side of the fixed range
   ATR_MULT       = 1  // Stop by current-timeframe ATR multiplier
  };

enum ENUM_DAY_STATE
  {
   DAY_FORMING = 0,
   DAY_ARMED   = 1,
   DAY_EXPIRED = 2,
   DAY_FLAT    = 3
  };

//=== Session engine ===
input group "Session Range"
input ENUM_SESSION_RANGE_MODE InpMode = MODE_BREAKOUT; // Strategy mode
input int             InpRangeStartHour = 2;           // Range start hour (server time)
input int             InpRangeStartMin  = 0;           // Range start minute
input int             InpRangeEndHour   = 10;          // Range end hour (server time)
input int             InpRangeEndMin    = 0;           // Range end minute
input int             InpTradeEndHour   = 13;          // No new entries after this time
input int             InpTradeEndMin    = 0;           // No new entries minute
input int             InpForceCloseHour = 19;          // Force close managed positions
input int             InpForceCloseMin  = 0;           // Force close minute
input bool            InpTradeOnFirstBar = false;      // Allow evaluating the last closed bar right after attach

//=== Trade ===
input group "Trade"
input ulong           InpMagic        = 770030;        // Magic Number
input ulong           InpDeviation    = 20;            // Max slippage in points
input double          InpMaxSpreadPts = 20.0;          // Entry spread cap in points; <=0 disables
input int             InpMaxLongPerDay  = 1;           // Daily long entries cap
input int             InpMaxShortPerDay = 1;           // Daily short entries cap

//=== Sizing and exits ===
input group "Sizing & Risk"
input double          InpRiskPercent = 0.5;            // Risk % of equity when InpFixedLots <= 0
input double          InpFixedLots   = 0.0;            // Fixed lots; <=0 uses risk sizing
input int             InpATRPeriod   = 14;             // ATR period for D1 quality and current-TF stop fallback
input double          InpRangeQualityK = 0.5;          // Range height must be < K * D1 ATR
input ENUM_SESSION_SL_MODE InpSLMode = RANGE_OPPOSITE;// Stop calculation mode
input double          InpSLATRMult   = 1.5;            // Current-TF ATR stop multiplier
input double          InpTPRR        = 1.5;            // TP = SL distance * RR; <=0 disables TP

//=== Optimization scoring ===
input group "Optimization"
input int             InpOptMinTrades       = 30;      // OnTester: minimum trades
input double          InpOptMinProfitFactor = 1.20;    // OnTester: reject PF below this
input double          InpOptMaxDDPercent    = 20.0;    // OnTester: reject equity DD% above this; <=0 disables
input int             InpOptTradeBoostCap   = 120;     // OnTester: cap sqrt(trades) boost

CTrade   trade;
int      atrD1Handle = INVALID_HANDLE;
int      atrTFHandle = INVALID_HANDLE;
datetime lastBar     = 0;
ENUM_ACCOUNT_MARGIN_MODE marginMode = ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;

int            g_sessionKey = 0;
ENUM_DAY_STATE g_dayState   = DAY_FORMING;
double         g_rangeHigh  = 0.0;
double         g_rangeLow   = 0.0;
int            g_rangeBars  = 0;
int            g_longsToday = 0;
int            g_shortsToday = 0;
bool           g_forceCloseDone = false;
bool           g_fadeWarningPrinted = false;

//+------------------------------------------------------------------+
int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int MakeMinute(const int hour, const int minute)
  {
   return hour * 60 + minute;
  }

int RangeStartMinute()
  {
   return MakeMinute(InpRangeStartHour, InpRangeStartMin);
  }

int RelFromRangeStartByMinute(const int minuteOfDay)
  {
   int rel = minuteOfDay - RangeStartMinute();
   if(rel < 0) rel += 1440;
   return rel;
  }

int RelFromRangeStartTime(const datetime t)
  {
   return RelFromRangeStartByMinute(MinuteOfDay(t));
  }

int RangeEndRel()
  {
   return RelFromRangeStartByMinute(MakeMinute(InpRangeEndHour, InpRangeEndMin));
  }

int TradeEndRel()
  {
   return RelFromRangeStartByMinute(MakeMinute(InpTradeEndHour, InpTradeEndMin));
  }

int ForceCloseRel()
  {
   return RelFromRangeStartByMinute(MakeMinute(InpForceCloseHour, InpForceCloseMin));
  }

int SessionKey(const datetime t)
  {
   datetime startDate = t;
   if(MinuteOfDay(t) < RangeStartMinute())
      startDate = t - 86400;

   MqlDateTime dt;
   TimeToStruct(startDate, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void ResetSession(const int key)
  {
   g_sessionKey = key;
   g_dayState = DAY_FORMING;
   g_rangeHigh = 0.0;
   g_rangeLow = 0.0;
   g_rangeBars = 0;
   g_longsToday = 0;
   g_shortsToday = 0;
   g_forceCloseDone = false;
  }

void EnsureSession(const datetime t)
  {
   int key = SessionKey(t);
   if(g_sessionKey != key)
      ResetSession(key);
  }

bool IsWithinRangeWindow(const datetime barTime)
  {
   int rel = RelFromRangeStartTime(barTime);
   return (rel >= 0 && rel < RangeEndRel());
  }

bool IsEntryWindow(const datetime barTime)
  {
   int rel = RelFromRangeStartTime(barTime);
   return (rel >= RangeEndRel() && rel < TradeEndRel());
  }

bool IsAfterTradeEnd(const datetime barTime)
  {
   return (RelFromRangeStartTime(barTime) >= TradeEndRel());
  }

bool IsAfterForceClose(const datetime t)
  {
   return (RelFromRangeStartTime(t) >= ForceCloseRel());
  }

//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0 || maxLot <= 0.0 || step <= 0.0)
     {
      PrintFormat("Invalid volume constraints min=%.4f max=%.4f step=%.4f, fail closed",
                  minLot, maxLot, step);
      return 0.0;
     }

   lots = MathFloor(lots / step + 1e-7) * step;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   return NormalizeDouble(lots, 8);
  }

double AlignDown(double price)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0.0) ts = _Point;
   if(ts <= 0.0) return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathFloor(price / ts + 1e-7) * ts, _Digits);
  }

double AlignUp(double price)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0.0) ts = _Point;
   if(ts <= 0.0) return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathCeil(price / ts - 1e-7) * ts, _Digits);
  }

double LotsByRisk(const double slDistance)
  {
   if(InpFixedLots > 0.0)
      return NormalizeLots(InpFixedLots);

   if(InpRiskPercent <= 0.0)
     {
      Print("InpRiskPercent <= 0 and InpFixedLots <= 0, skip entry");
      return 0.0;
     }

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   if(slDistance <= 0.0 || tickValue <= 0.0 || tickSize <= 0.0 || equity <= 0.0)
     {
      PrintFormat("Invalid risk inputs slDist=%.5f tickValue=%.5f tickSize=%.5f equity=%.2f, skip entry",
                  slDistance, tickValue, tickSize, equity);
      return 0.0;
     }

   double valuePerPricePerLot = tickValue / tickSize;
   double riskPerLot = slDistance * valuePerPricePerLot;
   if(riskPerLot <= 0.0)
      return 0.0;

   double riskAmount = (InpRiskPercent / 100.0) * equity;
   double lots = NormalizeLots(riskAmount / riskPerLot);
   if(lots <= 0.0)
      return 0.0;

   double actualRisk = lots * riskPerLot;
   if(actualRisk > riskAmount * 1.0001)
     {
      PrintFormat("Minimum/step-normalized lots %.2f risk %.2f exceeds limit %.2f, skip entry",
                  lots, actualRisk, riskAmount);
      return 0.0;
     }

   return lots;
  }

bool CanTradeDirection(const bool isBuy)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))           return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))   return false;

   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   if(isBuy && mode == SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(!isBuy && mode == SYMBOL_TRADE_MODE_LONGONLY)
      return false;
   return true;
  }

bool HasEnoughMargin(const ENUM_ORDER_TYPE type, const double lots, const double price)
  {
   double margin = 0.0;
   if(!OrderCalcMargin(type, _Symbol, lots, price, margin))
     {
      PrintFormat("OrderCalcMargin failed err=%d, fail closed", GetLastError());
      return false;
     }
   return (AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= margin);
  }

void CountManagedPositions(int &buyCount, int &sellCount)
  {
   buyCount = 0;
   sellCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)  buyCount++;
      if(type == POSITION_TYPE_SELL) sellCount++;
     }
  }

bool CloseAllManagedPositions()
  {
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;

      if(!trade.PositionClose(ticket))
        {
         allClosed = false;
         PrintFormat("Force close failed ticket=%I64u retcode=%u %s",
                     ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }
   return allClosed;
  }

void LogTradeResult(const string context, const bool sent)
  {
   uint rc = trade.ResultRetcode();
   if(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL)
      PrintFormat("%s filled: deal=%I64u order=%I64u vol=%.2f price=%.5f",
                  context, trade.ResultDeal(), trade.ResultOrder(), trade.ResultVolume(), trade.ResultPrice());
   else if(rc == TRADE_RETCODE_PLACED)
      PrintFormat("%s accepted: order=%I64u retcode=%u", context, trade.ResultOrder(), rc);
   else
      PrintFormat("%s failed: sent=%s retcode=%u %s err=%d",
                  context, (sent ? "true" : "false"), rc, trade.ResultRetcodeDescription(), GetLastError());
  }

bool IsNewBar()
  {
   datetime t[1];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, t) < 1)
      return false;
   return (t[0] != lastBar);
  }

//+------------------------------------------------------------------+
bool GetATRValues(double &atrD1, double &atrTF)
  {
   atrD1 = 0.0;
   atrTF = 0.0;

   if(BarsCalculated(atrD1Handle) < 2 || BarsCalculated(atrTFHandle) < 2)
      return false;

   double d1[1];
   double tf[1];
   if(CopyBuffer(atrD1Handle, 0, 1, 1, d1) < 1)
      return false;
   if(CopyBuffer(atrTFHandle, 0, 1, 1, tf) < 1)
      return false;

   atrD1 = d1[0];
   atrTF = tf[0];
   return (atrD1 > 0.0 && atrTF > 0.0);
  }

bool FinalizeRangeIfNeeded()
  {
   if(g_dayState != DAY_FORMING)
      return true;

   if(g_rangeBars <= 0 || g_rangeHigh <= 0.0 || g_rangeLow <= 0.0 || g_rangeHigh <= g_rangeLow)
     {
      g_dayState = DAY_EXPIRED;
      PrintFormat("Session %d expired: invalid or empty range bars=%d high=%.5f low=%.5f",
                  g_sessionKey, g_rangeBars, g_rangeHigh, g_rangeLow);
      return true;
     }

   double atrD1, atrTF;
   if(!GetATRValues(atrD1, atrTF))
     {
      PrintFormat("Session %d waiting for ATR data before range quality check", g_sessionKey);
      return false;
     }

   double rangeHeight = g_rangeHigh - g_rangeLow;
   double maxRange = MathMax(0.0, InpRangeQualityK) * atrD1;
   if(maxRange <= 0.0 || rangeHeight >= maxRange)
     {
      g_dayState = DAY_EXPIRED;
      PrintFormat("Session %d expired by range quality: height=%.5f max=%.5f D1ATR=%.5f K=%.2f",
                  g_sessionKey, rangeHeight, maxRange, atrD1, InpRangeQualityK);
      return true;
     }

   g_dayState = DAY_ARMED;
   PrintFormat("Session %d armed: high=%.5f low=%.5f height=%.5f D1ATR=%.5f bars=%d",
               g_sessionKey, g_rangeHigh, g_rangeLow, rangeHeight, atrD1, g_rangeBars);
   return true;
  }

void EnforceForceClose()
  {
   datetime now = TimeCurrent();
   EnsureSession(now);
   if(g_forceCloseDone || !IsAfterForceClose(now))
      return;

   if(CloseAllManagedPositions())
     {
      g_forceCloseDone = true;
      g_dayState = DAY_FLAT;
      PrintFormat("Session %d force close completed at %s", g_sessionKey, TimeToString(now, TIME_DATE|TIME_MINUTES));
     }
  }

bool SpreadAllowsEntry()
  {
   if(InpMaxSpreadPts <= 0.0)
      return true;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return false;

   double spreadPts = (ask - bid) / _Point;
   if(spreadPts > InpMaxSpreadPts)
     {
      PrintFormat("Spread %.1f > limit %.1f, skip entry", spreadPts, InpMaxSpreadPts);
      return false;
     }
   return true;
  }

bool BuildStops(const bool isBuy, const double entryPrice, const double bid, const double ask,
                const double atrTF, double &sl, double &tp, double &slDistance)
  {
   double spread = ask - bid;
   double stopsLevel  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double brokerMin = MathMax(stopsLevel, freezeLevel);
   double minDistance = brokerMin + MathMax(0.0, spread);

   double rangeDist = 0.0;
   if(isBuy)
      rangeDist = entryPrice - g_rangeLow;
   else
      rangeDist = g_rangeHigh - entryPrice;

   double atrDist = atrTF * InpSLATRMult;
   double chosenDist = atrDist;
   if(InpSLMode == RANGE_OPPOSITE)
     {
      chosenDist = MathMin(rangeDist, atrDist);
      if(chosenDist < minDistance)
         chosenDist = atrDist;
     }

   if(chosenDist < minDistance)
      chosenDist = minDistance;

   if(chosenDist <= 0.0)
      return false;

   if(isBuy)
     {
      sl = AlignDown(entryPrice - chosenDist);
      slDistance = entryPrice - sl;
      double tpDist = (InpTPRR > 0.0) ? MathMax(slDistance * InpTPRR, brokerMin) : 0.0;
      tp = (tpDist > 0.0) ? AlignUp(entryPrice + tpDist) : 0.0;

      if((bid - sl) < brokerMin)
        {
         PrintFormat("Buy SL distance too small %.5f < %.5f, skip entry", bid - sl, brokerMin);
         return false;
        }
      if(tp > 0.0 && (tp - bid) < brokerMin)
        {
         PrintFormat("Buy TP distance too small %.5f < %.5f, skip entry", tp - bid, brokerMin);
         return false;
        }
     }
   else
     {
      sl = AlignUp(entryPrice + chosenDist);
      slDistance = sl - entryPrice;
      double tpDist = (InpTPRR > 0.0) ? MathMax(slDistance * InpTPRR, brokerMin) : 0.0;
      tp = (tpDist > 0.0) ? AlignDown(entryPrice - tpDist) : 0.0;

      if((sl - ask) < brokerMin)
        {
         PrintFormat("Sell SL distance too small %.5f < %.5f, skip entry", sl - ask, brokerMin);
         return false;
        }
      if(tp > 0.0 && (ask - tp) < brokerMin)
        {
         PrintFormat("Sell TP distance too small %.5f < %.5f, skip entry", ask - tp, brokerMin);
         return false;
        }
     }

   return (slDistance > 0.0);
  }

bool OpenBreakoutPosition(const bool isBuy)
  {
   if(!CanTradeDirection(isBuy))
     {
      Print("Trading permission or symbol trade mode blocks this direction, skip entry");
      return false;
     }

   if(!SpreadAllowsEntry())
      return false;

   if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
        {
         PrintFormat("Netting/exchange account: %s has non-managed position magic=%I64d, skip entry",
                     _Symbol, PositionGetInteger(POSITION_MAGIC));
         return false;
        }
     }

   int buyCount, sellCount;
   CountManagedPositions(buyCount, sellCount);
   if(isBuy && g_longsToday >= InpMaxLongPerDay)
      return false;
   if(!isBuy && g_shortsToday >= InpMaxShortPerDay)
      return false;
   if(isBuy && buyCount > 0)
      return false;
   if(!isBuy && sellCount > 0)
      return false;
   if(isBuy && sellCount > 0)
     {
      Print("Managed short position is still open; skip opposite breakout buy.");
      return false;
     }
   if(!isBuy && buyCount > 0)
     {
      Print("Managed long position is still open; skip opposite breakout sell.");
      return false;
     }

   double atrD1, atrTF;
   if(!GetATRValues(atrD1, atrTF))
      return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double entryPrice = isBuy ? ask : bid;
   double sl = 0.0, tp = 0.0, slDistance = 0.0;
   if(!BuildStops(isBuy, entryPrice, bid, ask, atrTF, sl, tp, slDistance))
      return false;

   double lots = LotsByRisk(slDistance);
   if(lots <= 0.0)
      return false;

   ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!HasEnoughMargin(orderType, lots, entryPrice))
     {
      Print("Insufficient or unverified margin, skip entry");
      return false;
     }

   bool sent = false;
   if(isBuy)
      sent = trade.Buy(lots, _Symbol, 0.0, sl, tp, "SessionRange breakout buy");
   else
      sent = trade.Sell(lots, _Symbol, 0.0, sl, tp, "SessionRange breakout sell");

   LogTradeResult(isBuy ? "Breakout buy" : "Breakout sell", sent);

   uint rc = trade.ResultRetcode();
   bool accepted = (sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED));
   if(accepted)
     {
      if(isBuy) g_longsToday++;
      else      g_shortsToday++;
     }
   return accepted;
  }

bool ProcessClosedBar()
  {
   if(InpMode == MODE_FADE)
     {
      if(!g_fadeWarningPrinted)
        {
         Print("MODE_FADE is reserved for Asian Session Mean Reversion and is fail-closed in this build.");
         g_fadeWarningPrinted = true;
        }
      return true;
     }

   MqlRates bar[1];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, bar) < 1)
      return false;

   EnsureSession(bar[0].time);

   if(IsWithinRangeWindow(bar[0].time))
     {
      if(g_dayState == DAY_FORMING)
        {
         if(g_rangeBars == 0)
           {
            g_rangeHigh = bar[0].high;
            g_rangeLow  = bar[0].low;
           }
         else
           {
            g_rangeHigh = MathMax(g_rangeHigh, bar[0].high);
            g_rangeLow  = MathMin(g_rangeLow, bar[0].low);
           }
         g_rangeBars++;
        }
      return true;
     }

   if(!FinalizeRangeIfNeeded())
      return false;

   if(g_dayState == DAY_ARMED && IsAfterTradeEnd(bar[0].time))
     {
      g_dayState = DAY_EXPIRED;
      PrintFormat("Session %d expired after trade window without new entry", g_sessionKey);
      return true;
     }

   if(g_dayState != DAY_ARMED || !IsEntryWindow(bar[0].time))
      return true;

   bool buySig  = (bar[0].close > g_rangeHigh);
   bool sellSig = (bar[0].close < g_rangeLow);

   if(buySig && sellSig)
     {
      PrintFormat("Session %d ambiguous breakout close=%.5f high=%.5f low=%.5f, skip",
                  g_sessionKey, bar[0].close, g_rangeHigh, g_rangeLow);
      return true;
     }

   if(buySig)
      OpenBreakoutPosition(true);
   else if(sellSig)
      OpenBreakoutPosition(false);

   if(g_longsToday >= InpMaxLongPerDay && g_shortsToday >= InpMaxShortPerDay)
      g_dayState = DAY_EXPIRED;

   return true;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpRangeStartHour < 0 || InpRangeStartHour > 23 ||
      InpRangeEndHour   < 0 || InpRangeEndHour   > 23 ||
      InpTradeEndHour   < 0 || InpTradeEndHour   > 23 ||
      InpForceCloseHour < 0 || InpForceCloseHour > 23 ||
      InpRangeStartMin  < 0 || InpRangeStartMin  > 59 ||
      InpRangeEndMin    < 0 || InpRangeEndMin    > 59 ||
      InpTradeEndMin    < 0 || InpTradeEndMin    > 59 ||
      InpForceCloseMin  < 0 || InpForceCloseMin  > 59)
     {
      Print("Session time inputs must be valid server-time hour/minute values.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(RangeEndRel() <= 0 || RangeEndRel() >= TradeEndRel() || TradeEndRel() >= ForceCloseRel())
     {
      PrintFormat("Invalid session order: rangeEndRel=%d tradeEndRel=%d forceCloseRel=%d",
                  RangeEndRel(), TradeEndRel(), ForceCloseRel());
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpMaxLongPerDay < 0 || InpMaxShortPerDay < 0 || (InpMaxLongPerDay + InpMaxShortPerDay) <= 0)
     {
      Print("Daily entry caps must allow at least one direction.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpATRPeriod < 1 || InpRangeQualityK <= 0.0 || InpSLATRMult <= 0.0 || InpTPRR < 0.0)
     {
      Print("Invalid ATR/range-quality/SL/TP inputs.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpFixedLots <= 0.0 && InpRiskPercent <= 0.0)
     {
      Print("InpFixedLots <= 0 requires InpRiskPercent > 0.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpOptMinTrades < 1 || InpOptMinProfitFactor < 1.0 || InpOptTradeBoostCap < 1)
     {
      Print("Invalid optimization scoring inputs.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);

   atrD1Handle = iATR(_Symbol, PERIOD_D1, InpATRPeriod);
   if(atrD1Handle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create D1 ATR handle, err=%d", GetLastError());
      return INIT_FAILED;
     }

   atrTFHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(atrTFHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create current-timeframe ATR handle, err=%d", GetLastError());
      return INIT_FAILED;
     }

   marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   ResetSession(SessionKey(TimeCurrent()));

   if(InpTradeOnFirstBar)
      lastBar = 0;
   else
     {
      datetime t[1];
      lastBar = (CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, t) == 1) ? t[0] : 0;
     }

   PrintFormat("Strategy_Session_Range initialized: mode=%d range=%02d:%02d-%02d:%02d tradeEnd=%02d:%02d forceClose=%02d:%02d magic=%I64u",
               (int)InpMode,
               InpRangeStartHour, InpRangeStartMin,
               InpRangeEndHour, InpRangeEndMin,
               InpTradeEndHour, InpTradeEndMin,
               InpForceCloseHour, InpForceCloseMin,
               InpMagic);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(atrD1Handle != INVALID_HANDLE) IndicatorRelease(atrD1Handle);
   if(atrTFHandle != INVALID_HANDLE) IndicatorRelease(atrTFHandle);
  }

void OnTick()
  {
   EnforceForceClose();

   if(!IsNewBar())
      return;

   datetime curBar[1];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, curBar) < 1)
      return;

   if(!ProcessClosedBar())
      return;

   lastBar = curBar[0];
  }

//+------------------------------------------------------------------+
double OnTester()
  {
   double netProfit    = TesterStatistics(STAT_PROFIT);
   double ddPercent    = TesterStatistics(STAT_EQUITYDD_PERCENT);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery     = TesterStatistics(STAT_RECOVERY_FACTOR);
   int    trades       = (int)TesterStatistics(STAT_TRADES);

   int minTrades = MathMax(1, InpOptMinTrades);
   // Note: ddPercent == 0 is a legitimate (very low drawdown) run, not a reject
   // condition. Divide-by-zero in the ddPenalty term below is guarded by maxDD > 0.
   if(trades < minTrades ||
      netProfit <= 0.0 ||
      ddPercent < 0.0 ||
      recovery <= 0.0 ||
      profitFactor <= 0.0 ||
      !MathIsValidNumber(profitFactor) ||
      !MathIsValidNumber(recovery))
      return 0.0;

   double minPF = MathMax(1.0, InpOptMinProfitFactor);
   if(profitFactor < minPF)
      return 0.0;

   double maxDD = InpOptMaxDDPercent;
   if(maxDD > 0.0 && ddPercent > maxDD)
      return 0.0;

   int tradeCap = MathMax(minTrades, InpOptTradeBoostCap);
   double tradeBoost = MathSqrt((double)MathMin(trades, tradeCap));

   double ddPenalty = 1.0;
   if(maxDD > 0.0)
     {
      double ddRatio = MathMin(ddPercent / maxDD, 1.0);
      ddPenalty = 1.0 - 0.5 * ddRatio * ddRatio;
     }

   double pfEdge = profitFactor - minPF + 1.0;
   double score = recovery * pfEdge * tradeBoost * ddPenalty;
   if(score < 0.0 || !MathIsValidNumber(score)) score = 0.0;
   return score;
  }
//+------------------------------------------------------------------+
