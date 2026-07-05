//+------------------------------------------------------------------+
//|                                  Strategy_Weekend_Gap.mq5        |
//|                                                                  |
//|  Weekend Gap Fade research prototype for MT5.                    |
//|  This EA is intended for demo-forward evidence collection only.   |
//|  It fades the first weekly gap after waiting for the first M15     |
//|  bar to close and for spread to calm down.                         |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_WEEKEND_TP_MODE
  {
   TP_FULL_FILL  = 0, // TP at previous Friday close
   TP_PARTIAL_80 = 1  // TP at 80 percent gap fill
  };

//=== Gap definition ===
input group "Weekend Gap"
input double InpMinGapPips       = 5.0;     // Minimum absolute gap in pips
input double InpMinGapATRMult    = 0.3;     // Minimum gap also must exceed this * D1 ATR
input double InpMaxGapATRMult    = 1.5;     // Skip breakaway gaps above this * D1 ATR
input int    InpEntryDelayBars   = 1;       // M15 bars to wait after weekly open
input int    InpEntryWindowMins  = 60;      // Maximum minutes after weekly open to enter
input int    InpATRPeriod        = 14;      // D1 ATR period

//=== Execution ===
input group "Execution"
input ulong  InpMagic            = 770040;  // Magic Number
input ulong  InpDeviation        = 20;      // Max slippage in points
input double InpMaxSpreadPts     = 20.0;    // Entry spread cap in points; <=0 disables
input int    InpSpreadCalmBars   = 3;       // Completed M1 bars that must stay below spread cap

//=== Sizing and exits ===
input group "Sizing & Risk"
input double InpFixedLots        = 0.01;    // Fixed lots; used when InpRiskPercent <= 0
input double InpRiskPercent      = 0.0;     // Optional risk % of equity; <=0 uses fixed lots
input ENUM_WEEKEND_TP_MODE InpTPMode = TP_FULL_FILL; // Take-profit mode
input double InpSLGapMult        = 1.0;     // Stop distance = this * absolute gap
input double InpSLATRMult        = 1.0;     // ATR cap for stop distance; <=0 disables cap
input int    InpForceCloseDay    = 3;       // Force close day, server DOW: Sun=0 ... Wed=3
input int    InpForceCloseHour   = 0;       // Force close hour (server time)
input int    InpForceCloseMinute = 0;       // Force close minute

CTrade  trade;
int     atrD1Handle = INVALID_HANDLE;
string  gvLastTradeName = "";
ENUM_ACCOUNT_MARGIN_MODE marginMode = ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;

datetime g_lastTradedWeekOpen = 0;
datetime g_lastStaticSkipWeekOpen = 0;
datetime g_lastExpiredWeekOpen = 0;
datetime g_lastFilledWeekOpen = 0;

struct GapSetup
  {
   bool     valid;
   datetime prevCloseTime;
   datetime weekOpenTime;
   double   prevClose;
   double   weekOpen;
   double   gapPrice;
   double   atrD1;
  };

// Heavy gap scan is cached and refreshed at most once per M15 bar (see OnTick).
datetime g_lastScanBar = 0;
GapSetup g_setup;
bool     g_setupValid = false;

//+------------------------------------------------------------------+
double PipSize()
  {
   if(_Digits == 3 || _Digits == 5)
      return _Point * 10.0;
   return _Point;
  }

//+------------------------------------------------------------------+
int DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

//+------------------------------------------------------------------+
int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

//+------------------------------------------------------------------+
double CurrentSpreadPoints()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return DBL_MAX;
   return (ask - bid) / _Point;
  }

//+------------------------------------------------------------------+
double AlignDown(const double price)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;
   if(tickSize <= 0.0)
      return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathFloor(price / tickSize + 1e-7) * tickSize, _Digits);
  }

//+------------------------------------------------------------------+
double AlignUp(const double price)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;
   if(tickSize <= 0.0)
      return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathCeil(price / tickSize - 1e-7) * tickSize, _Digits);
  }

//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0 || maxLot <= 0.0 || step <= 0.0)
     {
      PrintFormat("Invalid volume constraints min=%.4f max=%.4f step=%.4f, fail closed",
                  minLot, maxLot, step);
      return 0.0;
     }

   lots = MathFloor(lots / step + 1e-7) * step;
   if(lots < minLot)
      lots = minLot;
   if(lots > maxLot)
      lots = maxLot;
   return NormalizeDouble(lots, 8);
  }

//+------------------------------------------------------------------+
double LotsByRisk(const double slDistance)
  {
   if(InpRiskPercent <= 0.0)
     {
      if(InpFixedLots <= 0.0)
        {
         Print("InpFixedLots <= 0 and InpRiskPercent <= 0, skip entry");
         return 0.0;
        }
      return NormalizeLots(InpFixedLots);
     }

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(slDistance <= 0.0 || tickValue <= 0.0 || tickSize <= 0.0 || equity <= 0.0)
     {
      PrintFormat("Invalid risk inputs slDist=%.5f tickValue=%.5f tickSize=%.5f equity=%.2f, skip entry",
                  slDistance, tickValue, tickSize, equity);
      return 0.0;
     }

   double valuePerPricePerLot = tickValue / tickSize;
   double riskPerLot = slDistance * valuePerPricePerLot;
   double riskAmount = equity * InpRiskPercent / 100.0;
   if(riskPerLot <= 0.0 || riskAmount <= 0.0)
      return 0.0;

   double lots = NormalizeLots(riskAmount / riskPerLot);
   if(lots <= 0.0)
      return 0.0;

   double actualRisk = lots * riskPerLot;
   if(actualRisk > riskAmount * 1.0001)
     {
      PrintFormat("Normalized lots %.2f risk %.2f exceeds limit %.2f, skip entry",
                  lots, actualRisk, riskAmount);
      return 0.0;
     }
   return lots;
  }

//+------------------------------------------------------------------+
bool HasManagedPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
void CloseManagedPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      if(!trade.PositionClose(ticket, InpDeviation))
        {
         PrintFormat("Force close failed ticket=%I64u retcode=%u desc=%s",
                     ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
      else
        {
         PrintFormat("Force close succeeded ticket=%I64u", ticket);
        }
     }
  }

//+------------------------------------------------------------------+
bool IsForceCloseTime(const datetime t)
  {
   int dow = DayOfWeek(t);
   int minute = MinuteOfDay(t);
   int closeMinute = InpForceCloseHour * 60 + InpForceCloseMinute;
   if(dow > InpForceCloseDay)
      return true;
   if(dow == InpForceCloseDay && minute >= closeMinute)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
double AtrD1At(const datetime t)
  {
   if(atrD1Handle == INVALID_HANDLE)
      return 0.0;

   int shift = iBarShift(_Symbol, PERIOD_D1, t, false);
   if(shift < 0)
      return 0.0;

   double buffer[1];
   if(CopyBuffer(atrD1Handle, 0, shift, 1, buffer) != 1)
      return 0.0;
   return buffer[0];
  }

//+------------------------------------------------------------------+
bool LatestGapSetup(GapSetup &setup)
  {
   setup.valid = false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M15, 0, 800, rates);
   if(copied < 10)
      return false;

   for(int i = 1; i < copied - 1; ++i)
     {
      MqlRates newer = rates[i];
      MqlRates older = rates[i + 1];
      if(newer.time <= older.time)
         continue;

      int gapSeconds = (int)(newer.time - older.time);
      if(gapSeconds < 24 * 60 * 60)
         continue;
      if(DayOfWeek(older.time) != 5)
         continue;

      setup.valid = true;
      setup.prevCloseTime = older.time;
      setup.weekOpenTime = newer.time;
      setup.prevClose = older.close;
      setup.weekOpen = newer.open;
      setup.gapPrice = setup.weekOpen - setup.prevClose;
      setup.atrD1 = AtrD1At(setup.prevCloseTime);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
bool SpreadIsCalm()
  {
   if(InpMaxSpreadPts <= 0.0)
      return true;

   double currentSpread = CurrentSpreadPoints();
   if(currentSpread > InpMaxSpreadPts)
      return false;

   if(InpSpreadCalmBars <= 0)
      return true;

   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   int copied = CopyRates(_Symbol, PERIOD_M1, 1, InpSpreadCalmBars, m1);
   if(copied < InpSpreadCalmBars)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      if(m1[i].spread <= 0)
         continue;
      if((double)m1[i].spread > InpMaxSpreadPts)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
bool AlreadyHandledWeek(const datetime weekOpen)
  {
   if(weekOpen <= 0)
      return true;
   if(g_lastTradedWeekOpen == weekOpen)
      return true;
   if(g_lastStaticSkipWeekOpen == weekOpen)
      return true;
   if(g_lastFilledWeekOpen == weekOpen)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
void RememberTradedWeek(const datetime weekOpen)
  {
   g_lastTradedWeekOpen = weekOpen;
   if(gvLastTradeName != "")
      GlobalVariableSet(gvLastTradeName, (double)weekOpen);
  }

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
// Pre-checks (already-handled week, open position, entry delay/window) are
// gated in OnTick; this runs only inside the active entry window with a valid
// cached setup.
void EvaluateEntry(const GapSetup &setup)
  {
   double absGap = MathAbs(setup.gapPrice);
   double pip = PipSize();
   if(pip <= 0.0 || absGap <= 0.0)
      return;

   if(setup.atrD1 <= 0.0)
     {
      PrintFormat("Weekend gap skipped: D1 ATR unavailable week_open=%s",
                  TimeToString(setup.weekOpenTime, TIME_DATE | TIME_MINUTES));
      g_lastStaticSkipWeekOpen = setup.weekOpenTime;
      return;
     }

   double minGap = MathMax(InpMinGapPips * pip, InpMinGapATRMult * setup.atrD1);
   double maxGap = InpMaxGapATRMult * setup.atrD1;
   if(absGap < minGap)
     {
      PrintFormat("Weekend gap skipped: too small gap=%.1f pips min=%.1f pips week_open=%s",
                  absGap / pip, minGap / pip, TimeToString(setup.weekOpenTime, TIME_DATE | TIME_MINUTES));
      g_lastStaticSkipWeekOpen = setup.weekOpenTime;
      return;
     }

   if(InpMaxGapATRMult > 0.0 && absGap > maxGap)
     {
      PrintFormat("Weekend gap skipped: breakaway gap=%.1f pips max=%.1f pips week_open=%s",
                  absGap / pip, maxGap / pip, TimeToString(setup.weekOpenTime, TIME_DATE | TIME_MINUTES));
      g_lastStaticSkipWeekOpen = setup.weekOpenTime;
      return;
     }

   if(!SpreadIsCalm())
      return;

   bool sell = (setup.gapPrice > 0.0);

   if(!CanTradeDirection(!sell))
     {
      Print("Trading permission or symbol trade mode blocks this direction, skip entry");
      return;
     }

   if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      if(PositionSelect(_Symbol) && (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
        {
         PrintFormat("Netting/exchange account: %s holds non-managed position, skip entry", _Symbol);
         return;
        }
     }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   double target = setup.prevClose;
   if(InpTPMode == TP_PARTIAL_80)
     {
      if(sell)
         target = setup.weekOpen - absGap * 0.8;
      else
         target = setup.weekOpen + absGap * 0.8;
     }

   if((sell && bid <= target) || (!sell && ask >= target))
     {
      PrintFormat("Weekend gap skipped: target already filled before entry week_open=%s",
                  TimeToString(setup.weekOpenTime, TIME_DATE | TIME_MINUTES));
      g_lastFilledWeekOpen = setup.weekOpenTime;
      return;
     }

   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;
   double minStopDistance = stopsLevel + tickSize;

   double slDistance = MathMax(absGap * MathMax(InpSLGapMult, 0.0), minStopDistance);
   if(InpSLATRMult > 0.0)
      slDistance = MathMax(MathMin(slDistance, setup.atrD1 * InpSLATRMult), minStopDistance);

   double lots = LotsByRisk(slDistance);
   if(lots <= 0.0)
      return;

   ENUM_ORDER_TYPE orderType = sell ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   if(!HasEnoughMargin(orderType, lots, sell ? bid : ask))
     {
      Print("Insufficient or unverified margin, skip entry");
      return;
     }

   double sl = 0.0;
   double tp = 0.0;
   bool sent = false;
   if(sell)
     {
      double entry = bid;
      tp = AlignDown(target);
      sl = AlignUp(entry + slDistance);
      if(entry - tp < minStopDistance || sl - entry < minStopDistance)
        {
         PrintFormat("Weekend gap sell skipped: TP/SL violates stop distance entry=%.5f tp=%.5f sl=%.5f",
                     entry, tp, sl);
         g_lastStaticSkipWeekOpen = setup.weekOpenTime;
         return;
        }
      sent = trade.Sell(lots, _Symbol, 0.0, sl, tp, "Weekend Gap Fade");
     }
   else
     {
      double entry = ask;
      tp = AlignUp(target);
      sl = AlignDown(entry - slDistance);
      if(tp - entry < minStopDistance || entry - sl < minStopDistance)
        {
         PrintFormat("Weekend gap buy skipped: TP/SL violates stop distance entry=%.5f tp=%.5f sl=%.5f",
                     entry, tp, sl);
         g_lastStaticSkipWeekOpen = setup.weekOpenTime;
         return;
        }
      sent = trade.Buy(lots, _Symbol, 0.0, sl, tp, "Weekend Gap Fade");
     }

   if(!sent)
     {
      PrintFormat("Weekend gap order failed week_open=%s lots=%.2f retcode=%u desc=%s",
                  TimeToString(setup.weekOpenTime, TIME_DATE | TIME_MINUTES),
                  lots, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return;
     }

   RememberTradedWeek(setup.weekOpenTime);
   PrintFormat("Weekend gap entry sent symbol=%s dir=%s week_open=%s gap=%.1f pips lots=%.2f sl=%.5f tp=%.5f",
               _Symbol, sell ? "SELL" : "BUY",
               TimeToString(setup.weekOpenTime, TIME_DATE | TIME_MINUTES),
               absGap / pip, lots, sl, tp);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(_Point <= 0.0)
      return INIT_FAILED;

   // --- Gap thresholds -------------------------------------------------------
   if(InpMinGapPips < 0.0 || InpMinGapATRMult < 0.0 || InpMaxGapATRMult < 0.0)
     {
      Print("Gap threshold inputs must be non-negative.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpMinGapPips <= 0.0 && InpMinGapATRMult <= 0.0)
     {
      Print("At least one minimum-gap floor (pips or ATR mult) must be > 0, else noise trades.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpMaxGapATRMult > 0.0 && InpMinGapATRMult > 0.0 && InpMinGapATRMult >= InpMaxGapATRMult)
     {
      Print("InpMinGapATRMult must be below InpMaxGapATRMult.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpATRPeriod < 1)
     {
      Print("InpATRPeriod must be >= 1.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // --- Entry timing ---------------------------------------------------------
   if(InpEntryDelayBars < 0 || InpEntryWindowMins <= 0)
     {
      Print("InpEntryDelayBars must be >= 0 and InpEntryWindowMins must be > 0.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(MathMax(InpEntryDelayBars, 0) * PeriodSeconds(PERIOD_M15) >= InpEntryWindowMins * 60)
     {
      Print("Entry delay must be shorter than the entry window, else no entry is ever possible.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // --- Spread filter (this strategy lives or dies on Monday-open spread) -----
   if(InpMaxSpreadPts <= 0.0 || InpSpreadCalmBars < 0)
     {
      Print("InpMaxSpreadPts must be > 0 and InpSpreadCalmBars >= 0.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // --- Sizing / SL ----------------------------------------------------------
   if(InpFixedLots <= 0.0 && InpRiskPercent <= 0.0)
     {
      Print("Provide InpFixedLots > 0 or InpRiskPercent > 0.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpSLGapMult <= 0.0)
     {
      Print("InpSLGapMult must be > 0 (primary SL basis).");
      return INIT_PARAMETERS_INCORRECT;
     }

   // --- Time exit: day must be Mon..Sat (0=Sunday would clash with the open) --
   if(InpForceCloseDay < 1 || InpForceCloseDay > 6 ||
      InpForceCloseHour < 0 || InpForceCloseHour > 23 ||
      InpForceCloseMinute < 0 || InpForceCloseMinute > 59)
     {
      Print("Force-close day must be 1..6 (Mon..Sat) with valid hour/minute.");
      return INIT_PARAMETERS_INCORRECT;
     }

   atrD1Handle = iATR(_Symbol, PERIOD_D1, InpATRPeriod);
   if(atrD1Handle == INVALID_HANDLE)
     {
      Print("Failed to create D1 ATR handle");
      return INIT_FAILED;
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints((uint)InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);

   marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);

   gvLastTradeName = StringFormat("WGAP_%I64d_%s_%I64u",
                                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, InpMagic);
   if(GlobalVariableCheck(gvLastTradeName))
      g_lastTradedWeekOpen = (datetime)GlobalVariableGet(gvLastTradeName);

   Print("Strategy_Weekend_Gap initialized: research prototype / demo-forward only");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(atrD1Handle != INVALID_HANDLE)
      IndicatorRelease(atrD1Handle);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime now = TimeCurrent();

   // Cheap: time-based exit runs every tick so it fires promptly at the cutoff.
   if(IsForceCloseTime(now))
     {
      if(HasManagedPosition())
         CloseManagedPositions();
     }

   // The heavy gap scan (CopyRates 800 M15) runs at most once per M15 bar; on
   // all other (idle) ticks we reuse the cached setup and fall through cheaply.
   datetime m15Time[1];
   if(CopyTime(_Symbol, PERIOD_M15, 0, 1, m15Time) == 1 && m15Time[0] != g_lastScanBar)
     {
      g_lastScanBar = m15Time[0];
      g_setupValid = LatestGapSetup(g_setup);
     }

   if(!g_setupValid)
      return;

   if(AlreadyHandledWeek(g_setup.weekOpenTime) || HasManagedPosition())
      return;

   int delaySeconds = MathMax(InpEntryDelayBars, 0) * PeriodSeconds(PERIOD_M15);
   if(now < g_setup.weekOpenTime + delaySeconds)
      return;

   if(InpEntryWindowMins > 0 && now > g_setup.weekOpenTime + InpEntryWindowMins * 60)
     {
      if(g_lastExpiredWeekOpen != g_setup.weekOpenTime)
        {
         PrintFormat("Weekend gap skipped: entry window expired week_open=%s",
                     TimeToString(g_setup.weekOpenTime, TIME_DATE | TIME_MINUTES));
         g_lastExpiredWeekOpen = g_setup.weekOpenTime;
        }
      return;
     }

   EvaluateEntry(g_setup);
  }
//+------------------------------------------------------------------+
