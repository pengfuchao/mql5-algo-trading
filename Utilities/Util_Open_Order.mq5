//+------------------------------------------------------------------+
//|                                              Util_Open_Order.mq5 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

CTrade trade; // 全域宣告 CTrade 物件

/* 
函數說明：新倉開單 (MT5 對沖帳戶適用)
參數說明：
          myType(開倉類型)：Buy or Sell
          myLots(開倉量)
          myLossStop(止損點數)
          myTakeProfit(止盈點數)
*/
void iOpenOrders(string myType, double myLots, int myLossStop, int myTakeProfit)
   {
      double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      
      double BuyLossStop = ask - myLossStop * point;
      double BuyTakeProfit = ask + myTakeProfit * point;
      double SellLossStop = bid + myLossStop * point;
      double SellTakeProfit = bid - myTakeProfit * point;
      
      if (myLossStop <= 0) //如果止損參數設為0
         {
            BuyLossStop = 0;
            SellLossStop = 0;
         }
      if (myTakeProfit <= 0) //如果止盈參數設為0
         {
            BuyTakeProfit = 0;
            SellTakeProfit = 0;
         }
         
      if (myType == "Buy")
         {
            trade.Buy(myLots, Symbol(), ask, BuyLossStop, BuyTakeProfit);
         }
      else if (myType == "Sell")
         {
            trade.Sell(myLots, Symbol(), bid, SellLossStop, SellTakeProfit);
         }
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Dummy event handler to prevent compilation error
  }
