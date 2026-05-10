//+------------------------------------------------------------------+
//|                                           Util_Trailing_Stop.mq5 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

CTrade trade_ts; // 全域 CTrade 物件

/* 
函數說明：移動止損 (MT5 對沖帳戶適用)
參數說明：myStopLoss 預設止損點數
功能說明：遍歷所有持倉訂單，當持倉單獲利達到止損點數時，修改止損價位。
*/
void iMoveStopLoss(int myStopLoss)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         long type = PositionGetInteger(POSITION_TYPE);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double current_sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
         
         // 多頭訂單，當前價格超過原止損價+設定點數時，上調止損
         if(profit > 0 && type == POSITION_TYPE_BUY)
           {
            // 如果原本沒有止損，或者價格已經超過移動範圍
            if(current_sl == 0 || (current_price - current_sl) > (2 * myStopLoss * point))
              {
               double new_sl = current_price - point * myStopLoss;
               trade_ts.PositionModify(ticket, new_sl, tp);
              }
           }
         // 空頭訂單，當前價格低於原止損價-設定點數時，下調止損
         else if(profit > 0 && type == POSITION_TYPE_SELL)
           {
            if(current_sl == 0 || (current_sl - current_price) > (2 * myStopLoss * point))
              {
               double new_sl = current_price + point * myStopLoss;
               trade_ts.PositionModify(ticket, new_sl, tp);
              }
           }
        }
     }
  }

/*
函數：移動止損進階版 (MT5)
輸入參數：myTicket 目標訂單號
          myTrallingLoss 移動止損點數
輸出參數：1-選定單出錯, 2-虧損訂單, 3-未達到移動止損價位, 0-修改成功
*/
int iTrallingLoss(ulong myTicket, int myTrallingLoss)
   {
      if(!PositionSelectByTicket(myTicket)) return(1); //選定單出錯
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit < 0) return(2); //虧損訂單不修改
      
      double myBasePrice = PositionGetDouble(POSITION_SL);
      if(myBasePrice == 0) myBasePrice = PositionGetDouble(POSITION_PRICE_OPEN);
         
      double myTLPrice;
      long type = PositionGetInteger(POSITION_TYPE);
      double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double tp = PositionGetDouble(POSITION_TP);
      
      if(type == POSITION_TYPE_BUY)
         {
            myTLPrice = current_price - myTrallingLoss * point;
            if(myBasePrice <= myTLPrice)
               {
                  trade_ts.PositionModify(myTicket, myTLPrice, tp);
                  return(0);
               }
         }
      else if(type == POSITION_TYPE_SELL)
         {
            myTLPrice = current_price + myTrallingLoss * point;
            if(myBasePrice == 0 || myBasePrice >= myTLPrice)
               {
                  trade_ts.PositionModify(myTicket, myTLPrice, tp);
                  return(0);
               }
         }
      return(3);
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Dummy event handler to prevent compilation error
  }
