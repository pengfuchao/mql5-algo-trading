//+------------------------------------------------------------------+
//|                                               Util_Close_All.mq5 |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

CTrade trade_ca;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   if (PositionsTotal() == 0)
   {
      Comment("沒有持倉單!!");
      return; //如果沒有持倉訂單，返回等待
   }
   
   string CurrentSymbol = Symbol();
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0 && PositionGetString(POSITION_SYMBOL) == CurrentSymbol)
      {
         if (trade_ca.PositionClose(ticket))
         {
            Comment("訂單" + IntegerToString(ticket) + "已平倉");
         }
      }
   }
}
//+------------------------------------------------------------------+
