//+------------------------------------------------------------------+
//|                                             Util_Display_Text.mq5 |
//+------------------------------------------------------------------+
/* 
函數說明：在螢幕上顯示標籤
參數說明：1. LableName 標籤名稱
          2. LableDoc  本文內容
          3. LableX    標籤x的位置
          4. LableY    標籤y的位置
          5. DocSize   文本字型大小
          6. DocStyle  文本字體
          7. DocColor  文本顏色
意思：用於在MetaTrader交易平台的圖表上創建並設置標籤（Label）
*/
void iSetLable(string LableName,string LableDoc,int LableX,int LableY,
              int DocSize,string DocStyle,color DocColor)
   {
      ObjectCreate(0, LableName, OBJ_LABEL, 0, 0, 0);
      ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
      ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
      ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
      ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
      ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
      ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
   }

/*
函    數：在螢幕上顯示文字標籤
輸入參數：string LableName 標籤名稱，如果顯示多個文本，名稱不能相同
          string LableDoc 文本內容
          int Corner 文本顯示角(0在左上角、1在右上角、2在左下角、3在右下角)
          int LableX 標籤X位置座標
          int LableY 標籤Y位置座標
          int DocSize 文本字型大小
          string DocStyle 文本字體
          color DocColor 文本顏色
*/
void iDisplayInfo(string LableName,string LableDoc,int Corner,int LableX,int LableY,int DocSize,string DocStyle,color DocColor)
   {
      // MT5 中通常直接畫在主圖表(0)上
      ObjectCreate(0, LableName, OBJ_LABEL, 0, 0, 0);
      ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
      ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
      ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
      ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
      ObjectSetInteger(0, LableName, OBJPROP_CORNER, Corner);
      ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
      ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  }
