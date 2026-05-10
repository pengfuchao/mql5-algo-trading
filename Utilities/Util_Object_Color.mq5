//+------------------------------------------------------------------+
//|                                              Util_Object_Color.mq5 |
//+------------------------------------------------------------------+
/*
函    數：物件顏色
輸入參數：double myInput 數值
輸出參數：顏色數值
算    法：負數為紅色，正數為綠色，0為灰色
*/
color iObjectColor(double myInput)
   {
      color myColor = clrDarkGray; // 0 顏色為灰色
      if (myInput > 0)
         myColor = clrGreen; // 正數顏色為綠色
      if (myInput < 0)
         myColor = clrRed; // 負數顏色為紅色
         
      return(myColor);
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  }
