//+------------------------------------------------------------------+
//|                                     Strategy_Turtle_Trading.mq5  |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input double Lots                 = 0.1;     // 指定交易的固定手數
input int    MaxUnits             = 3;       // 每個貨幣對的最大交易單位數
input ulong  MagicNumber          = 11282;
input int    EntryLookBack        = 55;      // 回溯計算突破價格的柱數
input int    ExitLookBack         = 20;      // 回溯計算退出點的柱數
input int    ATRPeriod            = 20;

input double SLMultiple           = 2.5;     // 止損 ATR 倍數
input double ReEntryMultiple      = 0.5;     // 重新進場 ATR 倍數
input bool   ATRBreakEven         = false;   // 移至保本水平
input double BreakEvenMultiple    = 2.5;     // 保本點 ATR 倍數
input bool   LockProfit           = true;    // 啟用利潤鎖定
input double PipLockinStart       = 50;      // 開始鎖定利潤的點數
input double LockinPercent        = 30;      // 利潤鎖定的百分比

CTrade trade;
int atrHandle;

double LastEMAX, LastEMIN;

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
   // 1. 取得 ATR
   double atrArray[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) < 1) return;
   double N = atrArray[0];
   
   // 2. 取得突破極值 (注意：MT5的 ArrayMaximum 是由左到右，我們直接用 CopyHigh 取得最近的 N 根)
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
   
   // 3. 盤點當前持倉與掛單
   int buyPositions = 0, sellPositions = 0;
   double lastBuyOpenPrice = 0, lastSellOpenPrice = 0;
   ulong buyStopTicket = 0, sellStopTicket = 0;
   double totalProfitPips = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         long type = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
         double volume = PositionGetDouble(POSITION_VOLUME);
         if(tickValue > 0 && volume > 0) totalProfitPips += (profit / volume / tickValue);
         
         if(type == POSITION_TYPE_BUY)
           {
            buyPositions++;
            if(openPrice > lastBuyOpenPrice) lastBuyOpenPrice = openPrice; // 取最高的買價
           }
         else if(type == POSITION_TYPE_SELL)
           {
            sellPositions++;
            if(lastSellOpenPrice == 0 || openPrice < lastSellOpenPrice) lastSellOpenPrice = openPrice; // 取最低的賣價
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
     
   // 4. 利潤鎖定邏輯 (簡單版)
   if(LockProfit && totalProfitPips > PipLockinStart)
     {
      // 若滿足條件直接平倉重新佈局
      CloseAllOrdersAndPositions();
      return;
     }
     
   // 5. 核心交易邏輯
   int totalPositions = buyPositions + sellPositions;
   
   // (A) 如果完全空倉，放置初始突破掛單
   if(totalPositions == 0)
     {
      double bStopLoss = NormalizeDouble(trueEMAX - N * SLMultiple, _Digits);
      double sStopLoss = NormalizeDouble(trueEMIN + N * SLMultiple, _Digits);
      
      // 更新 Buy Stop
      if(buyStopTicket == 0 || trueEMAX != LastEMAX)
        {
         if(buyStopTicket > 0) trade.OrderDelete(buyStopTicket);
         if(SymbolInfoDouble(Symbol(), SYMBOL_ASK) < trueEMAX)
           {
            trade.BuyStop(Lots, trueEMAX, Symbol(), bStopLoss, 0, ORDER_TIME_GTC, 0, "Turtle BuyStop");
            LastEMAX = trueEMAX;
           }
        }
      // 更新 Sell Stop
      if(sellStopTicket == 0 || trueEMIN != LastEMIN)
        {
         if(sellStopTicket > 0) trade.OrderDelete(sellStopTicket);
         if(SymbolInfoDouble(Symbol(), SYMBOL_BID) > trueEMIN)
           {
            trade.SellStop(Lots, trueEMIN, Symbol(), sStopLoss, 0, ORDER_TIME_GTC, 0, "Turtle SellStop");
            LastEMIN = trueEMIN;
           }
        }
     }
     
   // (B) 處理持有多單的情況
   if(buyPositions > 0)
     {
      if(sellStopTicket > 0) trade.OrderDelete(sellStopTicket); // 刪除反向掛單
      
      // 重新進場掛單 (加倉)
      if(buyPositions < MaxUnits && buyStopTicket == 0)
        {
         double nextBuyPrice = NormalizeDouble(lastBuyOpenPrice + N * ReEntryMultiple, _Digits);
         double nextSL = NormalizeDouble(nextBuyPrice - N * SLMultiple, _Digits);
         if(SymbolInfoDouble(Symbol(), SYMBOL_ASK) < nextBuyPrice)
            trade.BuyStop(Lots, nextBuyPrice, Symbol(), nextSL, 0, ORDER_TIME_GTC, 0, "Turtle Add Buy");
        }
        
      // 移動止損 (Trailing Stop)
      double newSL = NormalizeDouble(XMIN, _Digits); // 根據 ExitLookBack 移動止損
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               double currentSL = PositionGetDouble(POSITION_SL);
               if(newSL > currentSL || currentSL == 0)
                 {
                  trade.PositionModify(ticket, newSL, 0);
                 }
              }
           }
        }
     }
     
   // (C) 處理持有空單的情況
   if(sellPositions > 0)
     {
      if(buyStopTicket > 0) trade.OrderDelete(buyStopTicket); // 刪除反向掛單
      
      // 重新進場掛單 (加倉)
      if(sellPositions < MaxUnits && sellStopTicket == 0)
        {
         double nextSellPrice = NormalizeDouble(lastSellOpenPrice - N * ReEntryMultiple, _Digits);
         double nextSL = NormalizeDouble(nextSellPrice + N * SLMultiple, _Digits);
         if(SymbolInfoDouble(Symbol(), SYMBOL_BID) > nextSellPrice)
            trade.SellStop(Lots, nextSellPrice, Symbol(), nextSL, 0, ORDER_TIME_GTC, 0, "Turtle Add Sell");
        }
        
      // 移動止損 (Trailing Stop)
      double newSL = NormalizeDouble(XMAX, _Digits); // 根據 ExitLookBack 移動止損
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               double currentSL = PositionGetDouble(POSITION_SL);
               if(newSL < currentSL || currentSL == 0)
                 {
                  trade.PositionModify(ticket, newSL, 0);
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
void CloseAllOrdersAndPositions()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == MagicNumber)
        {
         trade.OrderDelete(ticket);
        }
     }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         trade.PositionClose(ticket);
        }
     }
  }
