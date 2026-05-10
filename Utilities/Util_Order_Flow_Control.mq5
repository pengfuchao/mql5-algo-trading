//+------------------------------------------------------------------+
//|                                     Util_Order_Flow_Control.mq5  |
//+------------------------------------------------------------------+
// 這不是一支可以單獨運行的 EA，而是「MT5 訂單流控管 (建倉、平倉、止損)」的程式碼片段範例。
// 請將這些片段複製到您的 EA (例如 Strategy_Template_MT5.mq5) 中使用。

void OnStart()
  {
   // 為了能通過編譯，保留空白的 OnStart
  }

/*
//--------------------------------------------------------------------------
// 1. 建倉與加倉 (Pyramiding) 邏輯
//--------------------------------------------------------------------------
   int BuyGroupOrders = 0; // 計算多單數量
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         BuyGroupOrders++;
     }

   string 交易信號 = "買入單建倉";
   
   if (BuyGroupOrders == 0 && 交易信號 == "買入單建倉")
     {
      // 執行買入單建倉 (呼叫 Util_Open_Order 的 iOpenOrders)
      // iOpenOrders("Buy", 0.1, 300, 600);
     }
   if (BuyGroupOrders == 1 && 交易信號 == "買入單建倉")
     {
      // 執行買入加倉
      // iOpenOrders("Buy", 0.1, 300, 600);
     }


//--------------------------------------------------------------------------
// 2. 禁止新開倉 (全平倉邏輯)
//--------------------------------------------------------------------------
   bool CloseAllBool = false;  
   if (BuyGroupOrders == 0)
     {
      CloseAllBool = false;  // 允許建倉
     }
   if (交易信號 == "買入單平倉" && BuyGroupOrders > 0)
     {
      CloseAllBool = true;   // 準備平倉，禁止建倉
     }

   if (CloseAllBool == true)
     {
      // 執行買入單平倉
      // iCloseOrders("Buy");
      return; 
     }

   // 增加了全平倉布林變數條件的建倉邏輯
   if (BuyGroupOrders == 0 && 交易信號 == "買入單建倉" && CloseAllBool == false)
     {
      // 執行買入單建倉
     }


//--------------------------------------------------------------------------
// 3. 繁忙等待函數 (MT5 改進版)
//--------------------------------------------------------------------------
   // MT5 的非同步架構不需要像 MT4 那樣用 IsTradeContextBusy()。
   // 在 MT5，只需確保 Terminal 連接正常並允許交易：
   bool iWait() 
     {
      int retries = 0;
      while ((!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) && retries < 10) 
        {
         Sleep(100);
         retries++;
        }
      return (retries < 10);
     }


//--------------------------------------------------------------------------
// 4. 清倉方式 (針對特定魔術數字和獲利條件)
//--------------------------------------------------------------------------
   int MyMagicNum = 123456;
   for(int cnt = PositionsTotal()-1; cnt >= 0; cnt--) 
     {
      ulong ticket = PositionGetTicket(cnt);
      if (ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MyMagicNum)
        {
         if (PositionGetDouble(POSITION_PROFIT) > 0) // 有獲利才平倉
           {
            // 呼叫平倉模組或直接使用 CTrade
            // trade.PositionClose(ticket);
           }
        }  
     }


//--------------------------------------------------------------------------
// 5. 密碼認證 & 到期日限制
//--------------------------------------------------------------------------
   // 限制EA有效期限
   if (TimeCurrent() > D'2026.12.31')
     {
      Print("軟體過期!");
      ExpertRemove(); // MT5 專用移除 EA 指令
      return;
     }

   // 密碼認證
   input string PassWord = "";
   if (PassWord != "pengfuzhao91222")
     {
      Print("密碼不正確!");
      ExpertRemove();
      return;
     }
*/
