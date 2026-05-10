//+------------------------------------------------------------------+
//|                                               Util_Draw_Line.mq5 |
//+------------------------------------------------------------------+
/* 
函數說明：兩點之間畫線
參數說明：1. myFirstTime    第一點時間
          2. myFirstPrice   第一點價格
          3. mySecondTime   第二點時間
          4. mySecondPrice  第二點價格
意思：用於在MetaTrader交易平台的圖表上畫一條趨勢線。
*/

int LineNo=0; // 定義並初始化一個全局變量 LineNo 為 0，用於標識趨勢線的編號

void iDrawLine(datetime myFirstTime, double myFirstPrice, datetime mySecondTime, double mySecondPrice)
   {
      string myObjectName = "Line" + IntegerToString(LineNo); // 創建一個趨勢線的名稱
      
      ObjectCreate(0, myObjectName, OBJ_TREND, 0, myFirstTime, myFirstPrice, mySecondTime, mySecondPrice); // 創建趨勢線對象
      ObjectSetInteger(0, myObjectName, OBJPROP_COLOR, clrGreen);      // 設置趨勢線的顏色為綠色
      ObjectSetInteger(0, myObjectName, OBJPROP_STYLE, STYLE_DOT);     // 設置趨勢線的樣式為點線
      ObjectSetInteger(0, myObjectName, OBJPROP_WIDTH, 1);             // 設置趨勢線的寬度為 1
      ObjectSetInteger(0, myObjectName, OBJPROP_BACK, false);          // 設置趨勢線不在背景顯示
      ObjectSetInteger(0, myObjectName, OBJPROP_RAY_RIGHT, false);     // 設置趨勢線向右不延長 (MT5用 OBJPROP_RAY_RIGHT)
      ObjectSetInteger(0, myObjectName, OBJPROP_RAY_LEFT, false);      // 設置趨勢線向左不延長
      
      LineNo++; // 將 LineNo 加 1，以便下一條趨勢線有不同的名稱
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  }
