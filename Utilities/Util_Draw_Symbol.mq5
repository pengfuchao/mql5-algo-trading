//+------------------------------------------------------------------+
//|                                             Util_Draw_Symbol.mq5 |
//+------------------------------------------------------------------+
/* 
函數說明：標註符號
(紅色頭為賣出，綠箭頭為買入，紅綠圓圈為其他標記)
參數說明：1. mySignal變數包括 a.Buy       買入箭頭
                              b.Sell      賣出箭頭
                              c.GreenMark 綠色圓圈
                              d.RedMark   紅色圓圈
                              
          2. myPrice 當前價格，符號標註位元
*/

void iDrawSign(string mySignal, double myPrice)
  {
   datetime time0 = iTime(Symbol(), PERIOD_CURRENT, 0); // 取得當前 K 線時間
   string timeStr = TimeToString(time0);
   
   // 如果信號是 "Buy"，則創建綠色箭頭，箭頭代碼為 241
   if (mySignal=="Buy")
      {
       string name = "BuyPoint-" + timeStr;
       ObjectCreate(0, name, OBJ_ARROW, 0, time0, myPrice);
       ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
       ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 241);
      }
   // 如果信號是 "Sell"，則創建紅色箭頭，箭頭代碼為 242
   if (mySignal=="Sell")
      {
       string name = "SellPoint-" + timeStr;
       ObjectCreate(0, name, OBJ_ARROW, 0, time0, myPrice);
       ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
       ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 242);
      }
   // 如果信號是 "GreenMark"，則創建綠色圓圈標記，代碼為 162
   if (mySignal=="GreenMark")
      {
       string name = "GreenMark-" + timeStr;
       ObjectCreate(0, name, OBJ_ARROW, 0, time0, myPrice);
       ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
       ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 162);
      }
   // 如果信號是 "RedMark"，則創建紅色圓圈標記，代碼為 162
   if (mySignal=="RedMark")
      {
       string name = "RedMark-" + timeStr;
       ObjectCreate(0, name, OBJ_ARROW, 0, time0, myPrice);
       ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
       ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 162);
      }
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  }
