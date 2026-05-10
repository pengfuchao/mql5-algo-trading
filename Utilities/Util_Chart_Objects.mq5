//+------------------------------------------------------------------+
//|                                           Util_Chart_Objects.mq5 |
//+------------------------------------------------------------------+
/*
函    數：標注k線文字
參數說明：string myString 文字內容，在指定的蠟燭位置顯示文字
          int myBarPos 指定k線序號
          double myPrice 指定價格
          string myDocStyle 指定字元集
          int myDocSize 指定字體大小
          color myColor 指定顏色
函數返回：在指定的k線價格位置上標注文字
*/
void iBarText(string myString,int myBarPos,double myPrice,string myDocStyle,int myDocSize,color myColor)
   {
      datetime barTime = iTime(Symbol(), PERIOD_CURRENT, myBarPos);
      string TextBarString = myString + TimeToString(barTime); //定義文本物件名稱
      
      ObjectCreate(0, TextBarString, OBJ_TEXT, 0, barTime, myPrice); //建立一個文本物件
      ObjectSetString(0, TextBarString, OBJPROP_TEXT, myString);      //文字內容
      ObjectSetString(0, TextBarString, OBJPROP_FONT, myDocStyle);    //字體
      ObjectSetInteger(0, TextBarString, OBJPROP_FONTSIZE, myDocSize);//字型大小
      ObjectSetInteger(0, TextBarString, OBJPROP_COLOR, myColor);     //顏色
   }

/*
函    數：k線指定位置畫水平線、垂直線或符號
參數說明：string myType HLine-畫水平線、VLine-畫垂直線、Dot-畫符號
          int myBarPos 指定蠟燭座標
          double myPrice 指定價格座標
          color myColor 符號顏色
          int mySymbol 符號代碼(例如108為圓點)
函數返回：在指定的蠟燭和價格位置標注符號或者畫水平線、垂直線
*/
void iDrawSign(string myType,int myBarPos,double myPrice,color myColor, int mySymbol)
   {
      datetime barTime = iTime(Symbol(), PERIOD_CURRENT, myBarPos);
      
      if (myType=="Dot")
         {
            string name = myType + TimeToString(barTime);
            ObjectCreate(0, name, OBJ_ARROW, 0, barTime, myPrice);
            ObjectSetInteger(0, name, OBJPROP_COLOR, myColor);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, mySymbol);
         }

      if (myType=="HLine")
         {
            string name = myType + TimeToString(barTime);
            ObjectCreate(0, name, OBJ_HLINE, 0, barTime, myPrice);
            ObjectSetInteger(0, name, OBJPROP_COLOR, myColor);
         }
         
      if (myType=="VLine")
         {
            string name = myType + TimeToString(barTime);
            ObjectCreate(0, name, OBJ_VLINE, 0, barTime, myPrice);
            ObjectSetInteger(0, name, OBJPROP_COLOR, myColor);
         }
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Dummy event handler to prevent compilation error
  }

