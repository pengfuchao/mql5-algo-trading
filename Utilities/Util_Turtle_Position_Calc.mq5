//+------------------------------------------------------------------+
//|                                     Util_Turtle_Position_Calc.mq5 |
//+------------------------------------------------------------------+
#property indicator_separate_window //設定指標顯示在單獨的窗口中。
#property indicator_plots 0 // 宣告此指標不畫線（僅使用圖表物件），解決編譯警告

input int ATRPeriod = 20; //設定 ATR 的週期為 20

int atrHandle;

int OnInit()
  {
   // 獲取 ATR 指標控制碼
   atrHandle = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("ATR 載入失敗");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, -1, OBJ_LABEL); //刪除主圖表中的所有標籤物件。
   Comment(""); //清除圖表上的所有評論。
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // 確保資料足夠
   if(rates_total < ATRPeriod) return(0);
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   // 獲取最新的 1 個 ATR 數值
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) return(0);
   
   double myATR = atrBuffer[0]; // ATR指標資料
   double myEquity = AccountInfoDouble(ACCOUNT_EQUITY);  //帳戶淨值
   double myTickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);  //單點價值
   double myLeverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);  //杠杆
   
   if(myTickValue > 0 && myLeverage > 0)
     {
      double myDvol = myATR * myTickValue; //絕對波幅
      double riskAmount = 0.01 * myEquity * (1.0 / myLeverage);
      double myUnit = 0;
      if(myDvol > 0) myUnit = iFundsToHands(Symbol(), riskAmount / myDvol); //單位頭寸
      
      double myMax = iFundsToHands(Symbol(), myEquity); //最大頭寸
      int myUnitNum = 0;
      if(myUnit > 0) myUnitNum = (int)(myMax / myUnit); //最大頭寸數量
      
      iDisplayInfo("AccountInfo1", "當前商品：" + Symbol(), 0, 10, 20, 8, "", clrSeaGreen);
      iDisplayInfo("PlatformRule1", "帳戶淨值：" + DoubleToString(myEquity, 2), 0, 200, 20, 8, "", clrSeaGreen);
      iDisplayInfo("AccountInfo2", "杠杆比例：1:" + DoubleToString(myLeverage, 0), 0, 10, 35, 8, "", clrSeaGreen);
      iDisplayInfo("PlatformRule4", "單點價值：" + DoubleToString(myTickValue, _Digits), 0, 200, 35, 8, "", clrSeaGreen);
      iDisplayInfo("AccountInfo3", " ATR讀數：" + DoubleToString(myATR, _Digits), 0, 10, 50, 8, "", clrSeaGreen);
      iDisplayInfo("AccountInfo6", "絕對波幅：" + DoubleToString(myDvol, _Digits), 0, 200, 50, 8, "", clrSeaGreen);
      iDisplayInfo("AccountInfo4", "單位頭寸：" + DoubleToString(myUnit, 2), 0, 10, 65, 8, "", clrSeaGreen);
      iDisplayInfo("PlatformRule2", "最大頭寸：" + DoubleToString(myMax, 2) + " / " + IntegerToString(myUnitNum), 0, 200, 65, 8, "", clrSeaGreen);
     }
     
   return(rates_total);
  }

/*
函    數：在螢幕上顯示文字標籤
*/
void iDisplayInfo(string LableName, string LableDoc, int Corner, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   if(Corner == -1) return;
   
   ObjectCreate(0, LableName, OBJ_LABEL, 0, 0, 0); //建立標籤物件
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc); //定義物件屬性
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   if(DocStyle != "") ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
   ObjectSetInteger(0, LableName, OBJPROP_CORNER, Corner);
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
  }

/*
函    數：金額轉換手數
*/
double iFundsToHands(string mySymbol, double myFunds)
  {
   double marginRequired = 0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, mySymbol, 1.0, SymbolInfoDouble(mySymbol, SYMBOL_ASK), marginRequired))
     {
      marginRequired = 1000;
     }
     
   double minLot = SymbolInfoDouble(mySymbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(mySymbol, SYMBOL_VOLUME_STEP);
   if(stepLot == 0) stepLot = minLot;
   
   double myLots = 0;
   if(marginRequired > 0)
     {
      myLots = myFunds / marginRequired; //換算可開倉手數
      myLots = MathRound(myLots / stepLot) * stepLot; //手數整形
      if(myLots < minLot) myLots = minLot;
     }
     
   return(myLots);
  }
