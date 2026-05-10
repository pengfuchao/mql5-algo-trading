//+------------------------------------------------------------------+
//|                                        Strategy_Template_MT5.mq5 |
//|                             現代化 MT5 EA 乾淨模板 (支援 Hedging) |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.00"

//====================================================================
// ⚠️【引入自定義工具模組】
// 為了讓這個 EA 可以編譯，請確保您將被引用的 Utilities 檔案中的
// void OnStart() { } 函數刪除，或是將檔案更名為 .mqh 副檔名。
// （因為 EA 只能有 OnInit, OnTick 等函數，不能包含腳本專用的 OnStart）
//====================================================================

// 取消下方註解即可引入我們寫好的模組：
// #include "..\Utilities\Util_Open_Order.mq5"
// #include "..\Utilities\Util_Close_Order.mq5"
// #include "..\Utilities\Util_Trailing_Stop.mq5"
// #include "..\Utilities\Util_Money_Management.mq5"

//--- EA 參數輸入區 (Inputs)
input double   InpLots        = 0.1;      // 預設開倉手數
input int      InpStopLoss    = 300;      // 止損點數 (Points)
input int      InpTakeProfit  = 600;      // 止盈點數 (Points)
input int      InpMagicNumber = 123456;   // EA 專屬特徵碼 (Magic Number)

//--- 全域變數宣告區
double point;

//+------------------------------------------------------------------+
//| EA 初始化函數 (取代 MT4 的 init)                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 取得點位資訊
   point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   
   // 可以在這裡設定 CTrade 物件的 Magic Number
   // (如果您有引入 Trade\Trade.mqh 或是我們的模組)
   // trade.SetExpertMagicNumber(InpMagicNumber);
   
   Print("EA 初始化成功！");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| EA 卸載函數 (取代 MT4 的 deinit)                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("EA 結束運行。");
   // 在這裡清除圖表標籤或畫線 (例如 ObjectsDeleteAll)
  }

//+------------------------------------------------------------------+
//| EA 主循環函數 (取代 MT4 的 start)                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   //=================================================================
   // 1. 條件判斷區 (進場信號)
   //=================================================================
   bool signalBuy = false;
   bool signalSell = false;
   
   // (在此撰寫您的指標邏輯，例如：均線交叉)
   // ...
   
   //=================================================================
   // 2. 訂單過濾與平倉區 (出場邏輯)
   //=================================================================
   // 假設觸發了平倉條件，您可以呼叫我們的平倉模組：
   // if(平倉條件滿足)
   // {
   //    iCloseOrders("Buy"); // 平掉所有多單
   // }
   
   //=================================================================
   // 3. 移動止損管理區
   //=================================================================
   // 讓 EA 每一跳都自動追蹤止損
   // iMoveStopLoss(150); // 獲利超過 150 點後開始移動止損
   
   //=================================================================
   // 4. 開倉下單區 (進場邏輯)
   //=================================================================
   // 檢查是否已經有持倉 (避免重複下單)
   int currentPositions = 0;
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(PositionGetSymbol(i) == Symbol()) currentPositions++;
     }
     
   if(currentPositions == 0) // 如果目前空手
     {
      // 根據信號下單 (呼叫我們的開倉模組)
      // if(signalBuy)  iOpenOrders("Buy", InpLots, InpStopLoss, InpTakeProfit);
      // if(signalSell) iOpenOrders("Sell", InpLots, InpStopLoss, InpTakeProfit);
     }
     
  }
//+------------------------------------------------------------------+
