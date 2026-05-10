//+------------------------------------------------------------------+
//|                                     Currency_Correlation.mq5 |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_plots 0

input string 貨幣對1 = "EURUSD";
input string 貨幣對2 = "USDCAD";
input int 取樣數量 = 300;

int OnInit()
  {
   // 每秒更新
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   int myWindowsHandle = ChartWindowFind();
   ObjectsDeleteAll(0, myWindowsHandle, OBJ_LABEL);
   Comment("");
  }
   
void OnTimer()
  {
   iMain();
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
   iMain();
   return(rates_total);
  }

void iMain()
  {
   if(取樣數量 <= 0) return;

   double open1[], open2[];
   // 嘗試獲取兩個貨幣對的 Open 數據
   if(CopyOpen(貨幣對1, PERIOD_CURRENT, 0, 取樣數量, open1) < 取樣數量)
     {
      iDisplayInfo("AccountInfo1", "等待數據載入: " + 貨幣對1, 0, 10, 20, 8, "", clrRed);
      return;
     }
   if(CopyOpen(貨幣對2, PERIOD_CURRENT, 0, 取樣數量, open2) < 取樣數量)
     {
      iDisplayInfo("AccountInfo1", "等待數據載入: " + 貨幣對2, 0, 10, 20, 8, "", clrRed);
      return;
     }

   double myAverage1 = 0, myAverage2 = 0;
   
   for(int i = 0; i < 取樣數量; i++)
     {
      myAverage1 += open1[i];
      myAverage2 += open2[i];
     }
   myAverage1 /= 取樣數量;
   myAverage2 /= 取樣數量;

   double mySum1 = 0, mySum2 = 0, mySum12 = 0;
   for(int i = 0; i < 取樣數量; i++)
     {
      mySum1 += MathPow((open1[i] - myAverage1), 2);
      mySum2 += MathPow((open2[i] - myAverage2), 2);
      mySum12 += (open1[i] - myAverage1) * (open2[i] - myAverage2);
     }
     
   double myCC = 0;
   if(mySum1 * mySum2 > 0)
     {
      myCC = mySum12 / MathSqrt(mySum1 * mySum2);
     }

   // 顯示資訊
   iDisplayInfo("AccountInfo1", "貨幣對1：" + 貨幣對1, 0, 10, 20, 8, "", clrSeaGreen);
   iDisplayInfo("PlatformRule1", "貨幣對2：" + 貨幣對2, 0, 200, 20, 8, "", clrSeaGreen);
   iDisplayInfo("AccountInfo2", "取樣數量：" + IntegerToString(取樣數量), 0, 10, 35, 8, "", clrSeaGreen);
   iDisplayInfo("PlatformRule4", "關係係數：" + DoubleToString(myCC * 100, 2) + "%", 0, 200, 35, 8, "", clrSeaGreen);
  } 

void iDisplayInfo(string LableName, string LableDoc, int CornerPos, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   if (CornerPos == -1) return;
   
   int myWindowsHandle = ChartWindowFind(); 
   if(myWindowsHandle < 0) myWindowsHandle = 0;
   
   LableName = LableName + IntegerToString(myWindowsHandle);
   
   ObjectCreate(0, LableName, OBJ_LABEL, myWindowsHandle, 0, 0); 
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc); 
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   if(DocStyle != "") ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor); 
   ObjectSetInteger(0, LableName, OBJPROP_CORNER, CornerPos); 
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX); 
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY); 
  }
