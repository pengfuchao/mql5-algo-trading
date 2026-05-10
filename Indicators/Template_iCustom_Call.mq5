//+------------------------------------------------------------------+
//|                                        Template_iCustom_Call.mq5 |
//+------------------------------------------------------------------+
// 這是一個 MT5 專用的教學範本，用來示範如何正確調用「自定義指標 (Custom Indicators)」。
// 在 MT5 中，不能像 MT4 那樣直接在主程式碼裡不斷呼叫 iCustom 取值，
// 必須使用「Handle (控制代碼)」與「CopyBuffer (複製緩衝區)」的架構。

#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

// 宣告全域的指標 Handle 變數
int handle_myCustomIndicator;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. 在 OnInit() 階段綁定指標 Handle (只執行一次)
   // 語法：iCustom(Symbol(), Period(), "指標路徑與名稱", 參數1, 參數2...)
   // 注意：如果您的指標在 Indicators 資料夾的子目錄中，路徑要寫完整，例如 "Examples\\MACD"
   
   handle_myCustomIndicator = iCustom(Symbol(), PERIOD_CURRENT, "Donchian_Channel", 20);
   
   // 檢查 Handle 是否綁定成功
   if(handle_myCustomIndicator == INVALID_HANDLE)
     {
      Print("無法載入自定義指標！錯誤碼：", GetLastError());
      return(INIT_FAILED);
     }
     
   Print("自定義指標 Handle 載入成功！");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 釋放指標 Handle，節省記憶體資源
   if(handle_myCustomIndicator != INVALID_HANDLE)
      IndicatorRelease(handle_myCustomIndicator);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 2. 在 OnTick() 中使用 CopyBuffer 抓取最新數據
   
   double upperBuffer[2]; // 準備一個小陣列來接上軌的資料
   double lowerBuffer[2]; // 準備一個小陣列來接下軌的資料
   
   // CopyBuffer(指標控制代碼, 緩衝區編號(Buffer_Index), 起始位置, 獲取數量, 接收陣列)
   // 在 MT5 中，0代表最新的K線(尚未收盤)，1代表上一根已經收盤的K線
   
   // 獲取上軌資料 (Buffer_Index = 0)
   int copiedUpper = CopyBuffer(handle_myCustomIndicator, 0, 0, 2, upperBuffer);
   
   // 獲取下軌資料 (Buffer_Index = 1)
   int copiedLower = CopyBuffer(handle_myCustomIndicator, 1, 0, 2, lowerBuffer);
   
   // 確保資料有成功抓下來
   if(copiedUpper > 0 && copiedLower > 0)
     {
      // 陣列排列預設最舊到最新，所以在這個宣告下，[1] 是最新 K 線的值，[0] 是上一根
      // 如果想要讓 [0] 永遠代表最新，可以在 CopyBuffer 前使用 ArraySetAsSeries(buffer, true);
      
      double currentUpper = upperBuffer[1]; // 當前 K 線上軌
      double currentLower = lowerBuffer[1]; // 當前 K 線下軌
      
      double previousUpper = upperBuffer[0]; // 上一根 K 線上軌
      double previousLower = lowerBuffer[0]; // 上一根 K 線下軌
      
      // 這裡可以加入您的交易邏輯 (例如：突破上軌買入)
      if(SymbolInfoDouble(Symbol(), SYMBOL_BID) > currentUpper)
        {
         // 執行買入...
         // Print("價格突破唐奇安通道上軌！");
        }
     }
   else
     {
      Print("獲取指標資料失敗，正在重試...");
     }
  }
//+------------------------------------------------------------------+
