//+------------------------------------------------------------------+
//|                                             Util_Close_Order.mq5 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

CTrade trade_co; // 為了避免與其他模組宣告衝突，使用不同的變數名稱或確保只宣告一次

/* 
函數說明：持倉單平倉 (MT5 對沖帳戶適用)
參數說明：
          平倉類型：1.Buy 多頭訂單
          (myType)  2.Sell空頭訂單
                    3.Profit 盈利訂單 
                    4.Loss   虧損訂單 
                    5.All    全部訂單
*/
void iCloseOrders(string myType)
  {
   // MT5 中使用 PositionsTotal() 來遍歷所有持倉
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         // 只處理當前圖表貨幣對的持倉
         if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
         
         long type = PositionGetInteger(POSITION_TYPE);
         double profit = PositionGetDouble(POSITION_PROFIT);
         
         if(myType == "All")
           {
            trade_co.PositionClose(ticket);
           }
         else if(myType == "Buy" && type == POSITION_TYPE_BUY)
           {
            trade_co.PositionClose(ticket);
           }
         else if(myType == "Sell" && type == POSITION_TYPE_SELL)
           {
            trade_co.PositionClose(ticket);
           }
         else if(myType == "Profit" && profit > 0)
           {
            trade_co.PositionClose(ticket);
           }
         else if(myType == "Loss" && profit < 0)
           {
            trade_co.PositionClose(ticket);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Dummy event handler to prevent compilation error
  }
