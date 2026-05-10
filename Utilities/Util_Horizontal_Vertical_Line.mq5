//+------------------------------------------------------------------+
//|                               Util_Horizontal_Vertical_Line.mq5 |
//+------------------------------------------------------------------+
/*
函    數：k線指定位置畫水平線、垂直線
參數說明：string myType HLine-畫水平線、VLine-畫垂直線、Dot-畫點
          int myBarPos 指定蠟燭座標 (向前的K線數)
          double myPrice 指定價格座標
          color myColor 符號顏色
          int mySymbol 符號代碼(例如108為圓點)
函數返回：在指定的蠟燭和價格位置標注符號或者畫水平線、垂直線
*/
void iDrawSign(string myType, int myBarPos, double myPrice, color myColor, int mySymbol)
   {
      datetime barTime = iTime(Symbol(), PERIOD_CURRENT, myBarPos);
      string timeStr = TimeToString(barTime);
      
      if (myType=="Dot")
         {
            string name = myType + timeStr;
            ObjectCreate(0, name, OBJ_ARROW, 0, barTime, myPrice);
            ObjectSetInteger(0, name, OBJPROP_COLOR, myColor);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, mySymbol);
         }

      if (myType=="HLine")
         {
            string name = myType + timeStr;
            ObjectCreate(0, name, OBJ_HLINE, 0, barTime, myPrice);
            ObjectSetInteger(0, name, OBJPROP_COLOR, myColor);
         }
         
      if (myType=="VLine")
         {
            string name = myType + timeStr;
            ObjectCreate(0, name, OBJ_VLINE, 0, barTime, myPrice);
            ObjectSetInteger(0, name, OBJPROP_COLOR, myColor);
         }
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // 第5根k線最高價位置畫藍色水平線
   iDrawSign("HLine", 5, iHigh(Symbol(), PERIOD_CURRENT, 5), clrBlue, 0);
   // 第4根k線最低價位置畫紅色垂直線
   iDrawSign("VLine", 4, iLow(Symbol(), PERIOD_CURRENT, 4), clrRed, 0);
  }
