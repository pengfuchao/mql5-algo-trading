//+------------------------------------------------------------------+
//|                                          Util_Iterate_Orders.mq5 |
//+------------------------------------------------------------------+
/*
MT5 對沖帳戶 (Hedging) 遍歷持倉訂單的標準寫法
*/
void IteratePositions()
   {
      if (PositionsTotal() > 0)
         {
            for (int i = PositionsTotal() - 1; i >= 0; i--)
               {
                  ulong ticket = PositionGetTicket(i);
                  if (ticket > 0)
                     {
                        // 確保是當前貨幣對
                        if (PositionGetString(POSITION_SYMBOL) == Symbol())
                           {
                              // 在這裡寫訂單操作語句
                              // 例如獲取訂單類型： long type = PositionGetInteger(POSITION_TYPE);
                              // 例如獲取利潤： double profit = PositionGetDouble(POSITION_PROFIT);
                           }
                     }
               }
         }
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  }
