//+------------------------------------------------------------------+
//|                                  Strategy_Time_Window.mq5        |
//|                                                                  |
//|  Generic time-window EA for MT5 research.                         |
//|  Built first for FX Time-of-Day Effect and intended for reuse by   |
//|  Gold Intraday Seasonality. It has no price signal: entries and    |
//|  exits are controlled only by broker server time, spread, and a    |
//|  distant D1 ATR catastrophe stop.                                  |
//|                                                                  |
//|  Time policy: conceptual rules may be defined in NY time, but all  |
//|  inputs below are broker server time. Defaults assume EET/EEST     |
//|  broker time: NY 03:00-11:00 ~= server 10:00-18:00, and NY         |
//|  11:00-16:00 ~= server 18:00-23:00. DST mismatch weeks may be      |
//|  off by one hour in v1.                                            |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_TIME_WINDOW_DIR
  {
   WINDOW_BUY  = 0,
   WINDOW_SELL = 1
  };

struct WindowConfig
  {
   bool                 enabled;
   ENUM_TIME_WINDOW_DIR direction;
   int                  openHour;
   int                  openMin;
   int                  closeHour;
   int                  closeMin;
   ulong                magic;
   string               label;
  };

struct WindowState
  {
   int                  initialSkipKey;
   int                  skippedKey;
   int                  lastOpenKey;
  };

//=== Window A ===
input group "Window A"
input bool                 InpUseWindowA       = true;        // Enable window A
input ENUM_TIME_WINDOW_DIR InpWindowADir       = WINDOW_SELL; // Window A direction
input int                  InpWindowAOpenHour  = 10;          // Window A open hour (server time)
input int                  InpWindowAOpenMin   = 0;           // Window A open minute
input int                  InpWindowACloseHour = 18;          // Window A close hour (server time)
input int                  InpWindowACloseMin  = 0;           // Window A close minute

//=== Window B ===
input group "Window B"
input bool                 InpUseWindowB       = true;       // Enable window B
input ENUM_TIME_WINDOW_DIR InpWindowBDir       = WINDOW_BUY; // Window B direction
input int                  InpWindowBOpenHour  = 18;         // Window B open hour (server time)
input int                  InpWindowBOpenMin   = 0;          // Window B open minute
input int                  InpWindowBCloseHour = 23;         // Window B close hour (server time)
input int                  InpWindowBCloseMin  = 0;          // Window B close minute

//=== Execution ===
input group "Execution"
input ulong                InpMagic              = 770020; // Window A magic; window B uses InpMagic+1
input ulong                InpDeviation          = 20;     // Max slippage in points
input double               InpMaxSpreadPts       = 15.0;   // Entry spread cap in points; <=0 disables
input int                  InpSpreadWaitMin      = 30;     // Max minutes after scheduled open to wait for spread
input int                  InpLateEntryGraceMin  = 60;     // Max minutes after scheduled open to allow late entry

//=== Sizing and risk ===
input group "Sizing & Risk"
input double               InpFixedLots          = 0.01;   // Fixed lots
input int                  InpATRPeriod          = 14;     // D1 ATR period for catastrophe SL
input double               InpCatastropheATRMult = 2.0;    // Catastrophe SL = D1 ATR * multiplier

//=== Weekend guard ===
input group "Weekend Guard"
input int                  InpFridayForceCloseHour = 23;   // Friday force-close hour (server time)
input int                  InpFridayForceCloseMin  = 0;    // Friday force-close minute

CTrade trade;
int atrD1Handle = INVALID_HANDLE;
ENUM_ACCOUNT_MARGIN_MODE marginMode = ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;

WindowState g_stateA;
WindowState g_stateB;
string      g_gvA = "";
string      g_gvB = "";

//+------------------------------------------------------------------+
int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

int MakeMinute(const int hour, const int minute)
  {
   return hour * 60 + minute;
  }

datetime MidnightOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int WindowOpenMinute(const WindowConfig &cfg)
  {
   return MakeMinute(cfg.openHour, cfg.openMin);
  }

int WindowCloseMinute(const WindowConfig &cfg)
  {
   return MakeMinute(cfg.closeHour, cfg.closeMin);
  }

bool WindowCrossesMidnight(const WindowConfig &cfg)
  {
   return WindowCloseMinute(cfg) <= WindowOpenMinute(cfg);
  }

void SessionTimes(const WindowConfig &cfg, const datetime now, datetime &openTime, datetime &closeTime)
  {
   datetime today = MidnightOf(now);
   int minuteNow = MinuteOfDay(now);
   int openMin = WindowOpenMinute(cfg);
   int closeMin = WindowCloseMinute(cfg);

   if(WindowCrossesMidnight(cfg))
     {
      if(minuteNow >= openMin)
        {
         openTime = today + openMin * 60;
         closeTime = today + 86400 + closeMin * 60;
        }
      else
        {
         openTime = today - 86400 + openMin * 60;
         closeTime = today + closeMin * 60;
        }
     }
   else
     {
      openTime = today + openMin * 60;
      closeTime = today + closeMin * 60;
     }
  }

string DirText(const ENUM_TIME_WINDOW_DIR direction)
  {
   return (direction == WINDOW_BUY) ? "BUY" : "SELL";
  }

double AlignDown(const double price)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;
   if(tickSize <= 0.0)
      return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathFloor(price / tickSize + 1e-7) * tickSize, _Digits);
  }

double AlignUp(const double price)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;
   if(tickSize <= 0.0)
      return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathCeil(price / tickSize - 1e-7) * tickSize, _Digits);
  }

double CurrentSpreadPoints()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return DBL_MAX;
   return (ask - bid) / _Point;
  }

bool SpreadAllowsEntry()
  {
   if(InpMaxSpreadPts <= 0.0)
      return true;

   double spread = CurrentSpreadPoints();
   if(spread > InpMaxSpreadPts)
     {
      PrintFormat("Spread %.1f > limit %.1f, wait/skip entry", spread, InpMaxSpreadPts);
      return false;
     }
   return true;
  }

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
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
     {
      PrintFormat("Insufficient margin: required=%.2f free=%.2f",
                  margin, AccountInfoDouble(ACCOUNT_MARGIN_FREE));
      return false;
     }
   return true;
  }

int CountManagedPositions(const ulong magic)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      count++;
     }
   return count;
  }

bool HasAnySymbolPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool CloseManagedPositions(const WindowConfig &cfg)
  {
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != cfg.magic)
         continue;

      if(!trade.PositionClose(ticket, InpDeviation))
        {
         allClosed = false;
         PrintFormat("%s close failed ticket=%I64u retcode=%u desc=%s",
                     cfg.label, ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
      else
        {
         PrintFormat("%s close sent ticket=%I64u retcode=%u desc=%s",
                     cfg.label, ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }
   return allClosed;
  }

void CloseAllManagedPositions()
  {
   WindowConfig a;
   WindowConfig b;
   BuildConfigs(a, b);
   if(a.enabled)
      CloseManagedPositions(a);
   if(b.enabled)
      CloseManagedPositions(b);
  }

bool IsFridayForceCloseTime(const datetime now)
  {
   int dow = DayOfWeek(now);
   int forceMin = MakeMinute(InpFridayForceCloseHour, InpFridayForceCloseMin);
   if(dow == 5 && MinuteOfDay(now) >= forceMin)
      return true;
   if(dow == 6 || dow == 0)
      return true;
   return false;
  }

bool IsWindowCloseDue(const WindowConfig &cfg, const datetime now)
  {
   datetime openTime = 0;
   datetime closeTime = 0;
   SessionTimes(cfg, now, openTime, closeTime);
   // A managed position should be held only while now is inside the active
   // [openTime, closeTime) window (SessionTimes already resolves cross-midnight
   // windows). Any other time -- past the close, or a stale position surviving
   // from a prior session before today's open -- is due to be closed.
   return !(now >= openTime && now < closeTime);
  }

bool EntriesBlockedByWeekend(const datetime now)
  {
   int dow = DayOfWeek(now);
   if(dow == 6 || dow == 0)
      return true;
   if(dow == 5 && MinuteOfDay(now) >= MakeMinute(InpFridayForceCloseHour, InpFridayForceCloseMin))
      return true;
   return false;
  }

bool FridayWindowWouldCrossGuard(const datetime openTime, const datetime closeTime)
  {
   if(DayOfWeek(openTime) != 5)
      return false;

   datetime fridayForceClose = MidnightOf(openTime) +
                               MakeMinute(InpFridayForceCloseHour, InpFridayForceCloseMin) * 60;
   return (closeTime >= fridayForceClose);
  }

double LatestD1ATR()
  {
   if(atrD1Handle == INVALID_HANDLE)
      return 0.0;
   if(BarsCalculated(atrD1Handle) < 2)
      return 0.0;

   double buffer[1];
   if(CopyBuffer(atrD1Handle, 0, 1, 1, buffer) != 1)
      return 0.0;
   return buffer[0];
  }

bool BuildCatastropheSL(const bool isBuy, const double entryPrice, double &sl, double &slDistance)
  {
   double atr = LatestD1ATR();
   if(atr <= 0.0)
     {
      Print("D1 ATR unavailable, skip entry");
      return false;
     }

   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;

   double minDistance = MathMax(stopsLevel, freezeLevel) + MathMax(tickSize, _Point);
   slDistance = MathMax(atr * InpCatastropheATRMult, minDistance);

   if(isBuy)
     {
      sl = AlignDown(entryPrice - slDistance);
      slDistance = entryPrice - sl;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || bid - sl < minDistance)
        {
         PrintFormat("Buy catastrophe SL too close: bid=%.5f sl=%.5f min=%.5f",
                     bid, sl, minDistance);
         return false;
        }
     }
   else
     {
      sl = AlignUp(entryPrice + slDistance);
      slDistance = sl - entryPrice;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0 || sl - ask < minDistance)
        {
         PrintFormat("Sell catastrophe SL too close: ask=%.5f sl=%.5f min=%.5f",
                     ask, sl, minDistance);
         return false;
        }
     }

   return (slDistance > 0.0);
  }

void PersistLastOpenKey(const WindowConfig &cfg, const int key)
  {
   string name = "";
   if(cfg.magic == InpMagic)
      name = g_gvA;
   else if(cfg.magic == InpMagic + 1)
      name = g_gvB;

   if(name != "")
      GlobalVariableSet(name, (double)key);
  }

bool OpenWindowPosition(const WindowConfig &cfg, WindowState &state, const int key)
  {
   bool isBuy = (cfg.direction == WINDOW_BUY);
   if(!CanTradeDirection(isBuy))
     {
      PrintFormat("%s trading permission or symbol trade mode blocks %s",
                  cfg.label, DirText(cfg.direction));
      return false;
     }

   if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && HasAnySymbolPosition())
     {
      PrintFormat("%s netting/exchange account already has a %s position, skip entry",
                  cfg.label, _Symbol);
      return false;
     }

   if(CountManagedPositions(cfg.magic) > 0)
      return false;

   if(!SpreadAllowsEntry())
      return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double entry = isBuy ? ask : bid;
   double sl = 0.0;
   double slDistance = 0.0;
   if(!BuildCatastropheSL(isBuy, entry, sl, slDistance))
      return false;

   double lots = NormalizeLots(InpFixedLots);
   if(lots <= 0.0)
      return false;

   ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!HasEnoughMargin(orderType, lots, entry))
      return false;

   trade.SetExpertMagicNumber(cfg.magic);
   bool sent = false;
   if(isBuy)
      sent = trade.Buy(lots, _Symbol, 0.0, sl, 0.0, cfg.label);
   else
      sent = trade.Sell(lots, _Symbol, 0.0, sl, 0.0, cfg.label);

   uint rc = trade.ResultRetcode();
   bool accepted = (sent && (rc == TRADE_RETCODE_DONE ||
                             rc == TRADE_RETCODE_DONE_PARTIAL ||
                             rc == TRADE_RETCODE_PLACED));
   if(!accepted)
     {
      PrintFormat("%s entry failed dir=%s lots=%.2f retcode=%u desc=%s err=%d",
                  cfg.label, DirText(cfg.direction), lots, rc,
                  trade.ResultRetcodeDescription(), GetLastError());
      return false;
     }

   state.lastOpenKey = key;
   PersistLastOpenKey(cfg, key);
   PrintFormat("%s entry accepted dir=%s key=%d lots=%.2f sl=%.5f deal=%I64u order=%I64u retcode=%u",
               cfg.label, DirText(cfg.direction), key, lots, sl,
               trade.ResultDeal(), trade.ResultOrder(), rc);
   return true;
  }

void EvaluateWindow(const WindowConfig &cfg, WindowState &state, const datetime now)
  {
   if(!cfg.enabled)
      return;

   datetime openTime = 0;
   datetime closeTime = 0;
   SessionTimes(cfg, now, openTime, closeTime);
   int key = DateKey(openTime);

   if(CountManagedPositions(cfg.magic) > 0 && IsWindowCloseDue(cfg, now))
     {
      CloseManagedPositions(cfg);
      return;
     }

   if(EntriesBlockedByWeekend(now))
      return;

   if(now < openTime || now >= closeTime)
      return;

   if(state.initialSkipKey == key || state.skippedKey == key || state.lastOpenKey == key)
      return;

   if(FridayWindowWouldCrossGuard(openTime, closeTime))
     {
      state.skippedKey = key;
      PrintFormat("%s skipped key=%d: Friday close %s is at/after force-close %s, preventing weekend hold",
                  cfg.label, key,
                  TimeToString(closeTime, TIME_DATE|TIME_MINUTES),
                  TimeToString(MidnightOf(openTime) + MakeMinute(InpFridayForceCloseHour, InpFridayForceCloseMin) * 60,
                               TIME_DATE|TIME_MINUTES));
      return;
     }

   int lateGrace = MathMax(0, InpLateEntryGraceMin);
   int spreadWait = MathMax(0, InpSpreadWaitMin);

   if(now > openTime + lateGrace * 60)
     {
      state.skippedKey = key;
      PrintFormat("%s skipped key=%d: late-entry grace expired now=%s open=%s",
                  cfg.label, key,
                  TimeToString(now, TIME_DATE|TIME_MINUTES),
                  TimeToString(openTime, TIME_DATE|TIME_MINUTES));
      return;
     }

   if(!SpreadAllowsEntry())
     {
      if(now > openTime + spreadWait * 60)
        {
         state.skippedKey = key;
         PrintFormat("%s skipped key=%d: spread did not calm within %d minutes",
                     cfg.label, key, spreadWait);
        }
      return;
     }

   OpenWindowPosition(cfg, state, key);
  }

void MarkInitialWindowSkip(const WindowConfig &cfg, WindowState &state, const datetime now)
  {
   if(!cfg.enabled)
      return;

   datetime openTime = 0;
   datetime closeTime = 0;
   SessionTimes(cfg, now, openTime, closeTime);
   if(now <= openTime || now >= closeTime)
      return;
   if(CountManagedPositions(cfg.magic) > 0)
      return;

   state.initialSkipKey = DateKey(openTime);
   PrintFormat("%s initial attach inside active window; key=%d skipped to avoid tester/startup look-ahead",
               cfg.label, state.initialSkipKey);
  }

void BuildConfigs(WindowConfig &a, WindowConfig &b)
  {
   a.enabled = InpUseWindowA;
   a.direction = InpWindowADir;
   a.openHour = InpWindowAOpenHour;
   a.openMin = InpWindowAOpenMin;
   a.closeHour = InpWindowACloseHour;
   a.closeMin = InpWindowACloseMin;
   a.magic = InpMagic;
   a.label = "TimeWindow A";

   b.enabled = InpUseWindowB;
   b.direction = InpWindowBDir;
   b.openHour = InpWindowBOpenHour;
   b.openMin = InpWindowBOpenMin;
   b.closeHour = InpWindowBCloseHour;
   b.closeMin = InpWindowBCloseMin;
   b.magic = InpMagic + 1;
   b.label = "TimeWindow B";
  }

bool ValidTime(const int hour, const int minute)
  {
   return (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59);
  }

bool ValidWindow(const string label,
                 const bool enabled,
                 const int openHour,
                 const int openMin,
                 const int closeHour,
                 const int closeMin)
  {
   if(!enabled)
      return true;

   if(!ValidTime(openHour, openMin) || !ValidTime(closeHour, closeMin))
     {
      PrintFormat("%s has invalid server-time hour/minute inputs.", label);
      return false;
     }

   if(MakeMinute(openHour, openMin) == MakeMinute(closeHour, closeMin))
     {
      PrintFormat("%s open and close cannot be the same time.", label);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!InpUseWindowA && !InpUseWindowB)
     {
      Print("At least one window must be enabled.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ValidWindow("Window A", InpUseWindowA, InpWindowAOpenHour, InpWindowAOpenMin,
                   InpWindowACloseHour, InpWindowACloseMin) ||
      !ValidWindow("Window B", InpUseWindowB, InpWindowBOpenHour, InpWindowBOpenMin,
                   InpWindowBCloseHour, InpWindowBCloseMin))
      return INIT_PARAMETERS_INCORRECT;

   if(!ValidTime(InpFridayForceCloseHour, InpFridayForceCloseMin))
     {
      Print("Friday force-close time inputs must be valid server-time hour/minute values.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpFixedLots <= 0.0 || InpATRPeriod < 1 || InpCatastropheATRMult <= 0.0)
     {
      Print("Invalid sizing/risk inputs: fixed lots, ATR period, and catastrophe ATR multiplier must be positive.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpSpreadWaitMin < 0 || InpLateEntryGraceMin < 0)
     {
      Print("Spread wait and late-entry grace must be non-negative.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpLateEntryGraceMin < InpSpreadWaitMin)
     {
      Print("InpLateEntryGraceMin should be >= InpSpreadWaitMin; otherwise spread wait can never finish.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetDeviationInPoints((uint)InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);
   marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);

   atrD1Handle = iATR(_Symbol, PERIOD_D1, InpATRPeriod);
   if(atrD1Handle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create D1 ATR handle, err=%d", GetLastError());
      return INIT_FAILED;
     }

   g_stateA.initialSkipKey = 0;
   g_stateA.skippedKey = 0;
   g_stateA.lastOpenKey = 0;
   g_stateB.initialSkipKey = 0;
   g_stateB.skippedKey = 0;
   g_stateB.lastOpenKey = 0;

   g_gvA = StringFormat("TW_%I64d_%s_%I64u_A",
                        AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, InpMagic);
   g_gvB = StringFormat("TW_%I64d_%s_%I64u_B",
                        AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, InpMagic + 1);
   if(GlobalVariableCheck(g_gvA))
      g_stateA.lastOpenKey = (int)GlobalVariableGet(g_gvA);
   if(GlobalVariableCheck(g_gvB))
      g_stateB.lastOpenKey = (int)GlobalVariableGet(g_gvB);

   WindowConfig a;
   WindowConfig b;
   BuildConfigs(a, b);
   datetime now = TimeCurrent();
   MarkInitialWindowSkip(a, g_stateA, now);
   MarkInitialWindowSkip(b, g_stateB, now);

   PrintFormat("Strategy_Time_Window initialized symbol=%s A=%s %s %02d:%02d-%02d:%02d magic=%I64u B=%s %s %02d:%02d-%02d:%02d magic=%I64u",
               _Symbol,
               InpUseWindowA ? "on" : "off", DirText(InpWindowADir),
               InpWindowAOpenHour, InpWindowAOpenMin, InpWindowACloseHour, InpWindowACloseMin, InpMagic,
               InpUseWindowB ? "on" : "off", DirText(InpWindowBDir),
               InpWindowBOpenHour, InpWindowBOpenMin, InpWindowBCloseHour, InpWindowBCloseMin, InpMagic + 1);
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

   WindowConfig a;
   WindowConfig b;
   BuildConfigs(a, b);

   if(IsFridayForceCloseTime(now))
      CloseAllManagedPositions();

   EvaluateWindow(a, g_stateA, now);
   EvaluateWindow(b, g_stateB, now);
  }
//+------------------------------------------------------------------+
