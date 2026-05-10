//+------------------------------------------------------------------+
//|                                            Util_Candle_Pattern.mq5 |
//+------------------------------------------------------------------+
/*
函    數：計算K線形態代碼
輸入參數：myBarShift-K線序號
輸出參數：K線形態代碼
算    法：代碼詳見文檔說明
*/
int iBarCode(int myBarShift)
   {
      int myReturn=0;
      double myOpen,myClose,myHigh,myLow; //定義K線4價格變數:開盤價、收盤價、最高價、最低價
      
      myOpen = iOpen(Symbol(), PERIOD_CURRENT, myBarShift);
      myClose = iClose(Symbol(), PERIOD_CURRENT, myBarShift);
      myHigh = iHigh(Symbol(), PERIOD_CURRENT, myBarShift);
      myLow = iLow(Symbol(), PERIOD_CURRENT, myBarShift);
      
      if (myOpen<myClose && myOpen==myLow && myClose==myHigh) myReturn=1; //光頭光腳陽線
      if (myOpen>myClose && myOpen==myHigh && myClose==myLow) myReturn=-1; //光頭光腳陰線
      if (myOpen<myClose && myOpen>myLow && myClose==myHigh) myReturn=2; //下引線陽線
      if (myOpen>myClose && myOpen==myHigh && myClose>myLow) myReturn=-2; //下引線陰線
      if (myOpen<myClose && myOpen==myLow && myClose<myHigh) myReturn=3; //上引線陽線
      if (myOpen>myClose && myOpen<myHigh && myClose==myLow) myReturn=-3; //上引線陰線
      if (myOpen<myClose && myOpen>myLow && myClose<myHigh) myReturn=4; //上下引線陽線
      if (myOpen>myClose && myOpen<myHigh && myClose>myLow) myReturn=-4; //上下引線陰線
      if (myOpen==myClose && myOpen==myLow && myClose<myHigh) myReturn=5; //倒T字型
      if (myOpen==myClose && myOpen==myHigh && myClose>myLow) myReturn=-5; //T字型
      if (myOpen==myClose && myOpen>myLow && myClose<myHigh) myReturn=6; //十字型
      if (myOpen==myClose && myOpen==myHigh && myClose==myLow) myReturn=-6; //一字型
      
      return(myReturn);
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Dummy event handler to prevent compilation error
  }
