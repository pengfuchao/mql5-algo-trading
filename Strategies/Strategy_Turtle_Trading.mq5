//+------------------------------------------------------------------+
//|                                     Strategy_Turtle_Trading.mq5  |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input bool   UseATRSizing         = true;    // 啟用 ATR 動態倉位 (海龜法則)
input double RiskPercent          = 1.0;     // 每單位風險：1N 波動對應的淨值百分比
input double Lots                 = 0.1;     // 固定手數 (UseATRSizing=false 時使用)
input int    MaxUnits             = 3;       // 每個貨幣對的最大交易單位數
input ulong  MagicNumber          = 11282;
input int    EntryLookBack        = 55;      // 回溯計算突破價格的柱數
input int    ExitLookBack         = 20;      // 回溯計算退出點的柱數
input int    ATRPeriod            = 20;

input double SLMultiple           = 2.5;     // 止損 ATR 倍數
input double ReEntryMultiple      = 0.5;     // 重新進場 ATR 倍數
input bool   ATRBreakEven         = false;   // 移至保本水平
input double BreakEvenMultiple    = 2.5;     // 保本點 ATR 倍數

CTrade trade;
int atrHandle;

double LastEMAX_Base = 0;
double LastEMIN_Base = 0;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| 手數正規化 (向下取整至 step，並夾在 min/max 之間)                |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   if(step <= 0) step = (minLot > 0 ? minLot : 0.01);

   lots = MathFloor(lots / step) * step;   // 向下取整，避免超出設定風險
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   return lots;
  }

//+------------------------------------------------------------------+
//| 海龜單位倉位：使 1N 的不利波動 ≈ RiskPercent% 淨值              |
//|   Unit = (RiskPercent% * Equity) / (N * 每點價值)               |
//|   止損為 SLMultiple*N，故單一單位最大虧損 ≈ SLMultiple*RiskPct% |
//+------------------------------------------------------------------+
double GetUnitLots(double N)
  {
   if(!UseATRSizing) return NormalizeLots(Lots);

   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   if(N <= 0 || tickValue <= 0 || tickSize <= 0) return NormalizeLots(Lots);

   double valuePerPriceUnitPerLot = tickValue / tickSize;       // 每 1.0 價格波動、每手的金額
   double dollarVolPerLot = N * valuePerPriceUnitPerLot;        // 每手在 1N 波動下的金額風險
   if(dollarVolPerLot <= 0) return NormalizeLots(Lots);

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = (RiskPercent / 100.0) * equity;
   return NormalizeLots(riskAmount / dollarVolPerLot);
  }

//+------------------------------------------------------------------+
//| 新 K 線判斷                                                      |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime currentTime[1];
   if(CopyTime(Symbol(), PERIOD_CURRENT, 0, 1, currentTime) < 1) return false;
   if(currentTime[0] != lastBarTime)
     {
      lastBarTime = currentTime[0];
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   
   atrHandle = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("無法載入 ATR 指標！");
      return(INIT_FAILED);
     }
     
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. 取得 ATR (採用上一根已收盤 K 棒，避免 N 於盤中跳動)
   double atrArray[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atrArray) < 1) return;
   double N = atrArray[0];

   // 經紀商最小停損/掛單距離 (避免 [Invalid stops] 拒單)
   double stopsLevel = (double)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   // 依當前波動率 (N) 與淨值計算每單位手數 (海龜動態倉位)
   double unitLots = GetUnitLots(N);

   // 判斷 Pip 乘數 (將 Points 轉為標準 Pips)
   double pipMultiplier = 1.0;
   if(_Digits == 5 || _Digits == 3) pipMultiplier = 10.0;
   
   // 2. 盤點當前持倉與掛單
   int buyPositions = 0, sellPositions = 0;
   double lastBuyOpenPrice = 0, lastSellOpenPrice = 0;
   ulong buyStopTicket = 0, sellStopTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         long type = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

         if(type == POSITION_TYPE_BUY)
           {
            buyPositions++;
            if(openPrice > lastBuyOpenPrice) lastBuyOpenPrice = openPrice; // 取最高的買價
            
            // 保本邏輯 (ATRBreakEven)
            if(ATRBreakEven)
              {
               double currentSL = PositionGetDouble(POSITION_SL);
               double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
               if(currentPrice - openPrice >= BreakEvenMultiple * N)
                 {
                  double breakEvenSL = NormalizeDouble(openPrice + 2 * _Point * pipMultiplier, _Digits);
                  if(currentSL < openPrice) trade.PositionModify(ticket, breakEvenSL, 0);
                 }
              }
           }
         else if(type == POSITION_TYPE_SELL)
           {
            sellPositions++;
            if(lastSellOpenPrice == 0 || openPrice < lastSellOpenPrice) lastSellOpenPrice = openPrice; // 取最低的賣價
            
            // 保本邏輯 (ATRBreakEven)
            if(ATRBreakEven)
              {
               double currentSL = PositionGetDouble(POSITION_SL);
               double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
               if(openPrice - currentPrice >= BreakEvenMultiple * N)
                 {
                  double breakEvenSL = NormalizeDouble(openPrice - 2 * _Point * pipMultiplier, _Digits);
                  if(currentSL > openPrice || currentSL == 0) trade.PositionModify(ticket, breakEvenSL, 0);
                 }
              }
           }
        }
     }
     
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == MagicNumber)
        {
         long type = OrderGetInteger(ORDER_TYPE);
         if(type == ORDER_TYPE_BUY_STOP) buyStopTicket = ticket;
         if(type == ORDER_TYPE_SELL_STOP) sellStopTicket = ticket;
        }
     }

   // 2.1 持倉一旦確立，立即(每 tick)取消反向突破掛單，
   //     避免同一根 K 線內被反向掛單成交而形成多空對沖
   if(buyPositions > 0 && sellStopTicket > 0)
     {
      if(trade.OrderDelete(sellStopTicket)) sellStopTicket = 0;
     }
   if(sellPositions > 0 && buyStopTicket > 0)
     {
      if(trade.OrderDelete(buyStopTicket)) buyStopTicket = 0;
     }

   // 3. 加倉邏輯 (確保能迅速補上下一階掛單)
   if(buyPositions > 0 && buyPositions < MaxUnits && buyStopTicket == 0)
     {
      double nextBuyPrice = NormalizeDouble(lastBuyOpenPrice + N * ReEntryMultiple, _Digits);
      double nextSL = NormalizeDouble(nextBuyPrice - MathMax(N * SLMultiple, stopsLevel), _Digits);
      // BuyStop 須高於 Ask 至少 stopsLevel，否則經紀商拒單
      if(SymbolInfoDouble(Symbol(), SYMBOL_ASK) + stopsLevel < nextBuyPrice)
         trade.BuyStop(unitLots, nextBuyPrice, Symbol(), nextSL, 0, ORDER_TIME_GTC, 0, "Turtle Add Buy");
     }
   if(sellPositions > 0 && sellPositions < MaxUnits && sellStopTicket == 0)
     {
      double nextSellPrice = NormalizeDouble(lastSellOpenPrice - N * ReEntryMultiple, _Digits);
      double nextSL = NormalizeDouble(nextSellPrice + MathMax(N * SLMultiple, stopsLevel), _Digits);
      // SellStop 須低於 Bid 至少 stopsLevel，否則經紀商拒單
      if(SymbolInfoDouble(Symbol(), SYMBOL_BID) - stopsLevel > nextSellPrice)
         trade.SellStop(unitLots, nextSellPrice, Symbol(), nextSL, 0, ORDER_TIME_GTC, 0, "Turtle Add Sell");
     }

   // 4. 新 K 線核心判斷：進場掛單與追蹤止損
   if(!IsNewBar()) return;
   
   double eHigh[], eLow[], xHigh[], xLow[];
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 1, EntryLookBack, eHigh) < EntryLookBack) return;
   if(CopyLow(Symbol(), PERIOD_CURRENT, 1, EntryLookBack, eLow) < EntryLookBack) return;
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 1, ExitLookBack, xHigh) < ExitLookBack) return;
   if(CopyLow(Symbol(), PERIOD_CURRENT, 1, ExitLookBack, xLow) < ExitLookBack) return;
   
   double EMAX = eHigh[ArrayMaximum(eHigh)];
   double EMIN = eLow[ArrayMinimum(eLow)];
   double XMAX = xHigh[ArrayMaximum(xHigh)];
   double XMIN = xLow[ArrayMinimum(xLow)];
   
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point;
   double trueEMAX = EMAX + spread;
   double trueEMIN = EMIN - spread;
   
   int totalPositions = buyPositions + sellPositions;
   
   // (A) 如果完全空倉，放置初始突破掛單
   if(totalPositions == 0)
     {
      double bStopLoss = NormalizeDouble(trueEMAX - MathMax(N * SLMultiple, stopsLevel), _Digits);
      double sStopLoss = NormalizeDouble(trueEMIN + MathMax(N * SLMultiple, stopsLevel), _Digits);

      if(buyStopTicket == 0 || EMAX != LastEMAX_Base)
        {
         if(SymbolInfoDouble(Symbol(), SYMBOL_ASK) + stopsLevel < trueEMAX)
           {
            if(buyStopTicket > 0) trade.OrderDelete(buyStopTicket);
            trade.BuyStop(unitLots, trueEMAX, Symbol(), bStopLoss, 0, ORDER_TIME_GTC, 0, "Turtle BuyStop");
            LastEMAX_Base = EMAX;
           }
        }
      if(sellStopTicket == 0 || EMIN != LastEMIN_Base)
        {
         if(SymbolInfoDouble(Symbol(), SYMBOL_BID) - stopsLevel > trueEMIN)
           {
            if(sellStopTicket > 0) trade.OrderDelete(sellStopTicket);
            trade.SellStop(unitLots, trueEMIN, Symbol(), sStopLoss, 0, ORDER_TIME_GTC, 0, "Turtle SellStop");
            LastEMIN_Base = EMIN;
           }
        }
     }
     
   // (B) 處理持有多單的追蹤止損 (反向掛單已於每 tick 區塊取消)
   if(buyPositions > 0)
     {
      // 止損不可貼現價過近，否則拒單；與現有 SL 差距過小則不重送 (避免冗餘修改)
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double newSL = NormalizeDouble(MathMin(XMIN, bid - stopsLevel), _Digits);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               double currentSL = PositionGetDouble(POSITION_SL);
               if(newSL > currentSL + _Point || currentSL == 0) trade.PositionModify(ticket, newSL, 0);
              }
           }
        }
     }

   // (C) 處理持有空單的追蹤止損 (反向掛單已於每 tick 區塊取消)
   if(sellPositions > 0)
     {
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double newSL = NormalizeDouble(MathMax(XMAX, ask + stopsLevel), _Digits);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               double currentSL = PositionGetDouble(POSITION_SL);
               if((newSL < currentSL - _Point && newSL > 0) || currentSL == 0) trade.PositionModify(ticket, newSL, 0);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
