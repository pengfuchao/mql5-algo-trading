//+------------------------------------------------------------------+
//|                                           Strategy_First_EA.mq5  |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- EA 參數宣告
input double InpLots = 0.01;      // 下單手數
input int maPeriod = 20;       // MA指標Period參數
input ulong magicNumber = 111; // EA 魔術數字

//--- 全域變數宣告
CTrade trade;
int maHandle;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(magicNumber);
   
   // 取得 MA 指標 Handle
   maHandle = iMA(Symbol(), PERIOD_CURRENT, maPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE)
     {
      Print("無法載入 MA 指標！");
      return(INIT_FAILED);
     }
     
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Alert("移除EA");
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. K棒收定時執行進出場判斷 (利用時間戳檢查新K棒)
   datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime) return; // 還在同一根 K 線，直接返回
   
   lastBarTime = currentBarTime; // 記錄最新 K 線時間
   
   // 取得 Close[1] 與 MA[1]
   double closeArray[2];
   if(CopyClose(Symbol(), PERIOD_CURRENT, 0, 2, closeArray) < 2) return;
   double close1 = closeArray[0]; // CopyClose 預設陣列 [0] 是舊的，[1] 是新的 (索引0為最新K線上的一根)
   
   double maArray[2];
   if(CopyBuffer(maHandle, 0, 0, 2, maArray) < 2) return;
   double ma1 = maArray[0]; // MA 的上一根值
   
   // 檢查目前是否持有本 EA 的多單
   bool hasBuyPosition = false;
   ulong currentTicket = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            hasBuyPosition = true;
            currentTicket = ticket;
            break;
           }
        }
     }
   
   // 2. 收盤價大於 MA 進多單 (若無持倉)
   if(!hasBuyPosition && close1 > ma1)
     {
      trade.Buy(InpLots, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_ASK), 0, 0, "First EA Buy");
     }
     
   // 3. 收盤價小於 MA 平倉多單 (若有持倉)
   if(hasBuyPosition && close1 < ma1)
     {
      trade.PositionClose(currentTicket);
     }
  }
//+------------------------------------------------------------------+
