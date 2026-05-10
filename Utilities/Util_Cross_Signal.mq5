//+------------------------------------------------------------------+
//|                                            Util_Cross_Signal.mq5 |
//+------------------------------------------------------------------+
/*
函    數:計算指標交叉信號
輸入參數:double myFast0:當前快線值
         double mySlow0:當前慢線值
         double myFast1:前一快線值
         double mySlow1:前一慢線值
輸出參數:向上交叉為0,向下交叉為1,無效交叉為9
算    法：判斷快線是否穿過慢線
*/
int iCrossSignal(double myFast0,double mySlow0,double myFast1,double mySlow1)
   {
      int myReturn=9;
      if (myFast0>mySlow0 && myFast1<=mySlow1)
         {
            myReturn=0;
         }
      if (myFast0<mySlow0 && myFast1>=mySlow1)
         {
            myReturn=1;
         }
      return(myReturn);
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Dummy event handler to prevent compilation error
  }

