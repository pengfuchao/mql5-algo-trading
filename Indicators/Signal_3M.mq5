//+------------------------------------------------------------------+
//|                                                   Signal_3M.mq5 |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "3MSignal"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrNONE

input int 圖表週期1 = 1;
input int 圖表週期2 = 5;
input int 圖表週期3 = 30;

input int 均線平均週期 = 5;
input ENUM_MA_METHOD 均線平均方法 = MODE_SMMA;
input ENUM_APPLIED_PRICE 均線使用價格 = PRICE_CLOSE;

input int 布林平均週期 = 10;
input double 布林偏差值 = 2.0;
input ENUM_APPLIED_PRICE 布林使用價格 = PRICE_CLOSE;

double SignalBuffer[];

ENUM_TIMEFRAMES TimeFrame1, TimeFrame2, TimeFrame3;
string Frame1, Frame2, Frame3;

int handle_ma1, handle_ma2, handle_ma3;
int handle_bands1, handle_bands2, handle_bands3;

//+------------------------------------------------------------------+
//| Helper: int 轉 ENUM_TIMEFRAMES                                     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES IntToPeriod(int tf)
  {
   switch(tf)
     {
      case 1: return PERIOD_M1;
      case 5: return PERIOD_M5;
      case 15: return PERIOD_M15;
      case 30: return PERIOD_M30;
      case 60: return PERIOD_H1;
      case 240: return PERIOD_H4;
      case 1440: return PERIOD_D1;
      case 10080: return PERIOD_W1;
      case 43200: return PERIOD_MN1;
      default: return PERIOD_CURRENT;
     }
  }

string PeriodToString(ENUM_TIMEFRAMES period)
  {
   switch(period)
     {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "Current";
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   TimeFrame1 = (圖表週期1 == 0) ? Period() : IntToPeriod(圖表週期1);
   TimeFrame2 = (圖表週期2 == 0) ? Period() : IntToPeriod(圖表週期2);
   TimeFrame3 = (圖表週期3 == 0) ? Period() : IntToPeriod(圖表週期3);

   Frame1 = PeriodToString(TimeFrame1);
   Frame2 = PeriodToString(TimeFrame2);
   Frame3 = PeriodToString(TimeFrame3);

   // 設置指標屬性
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   SetIndexBuffer(0, SignalBuffer, INDICATOR_DATA);

   // 建立 Handles
   handle_ma1 = iMA(Symbol(), TimeFrame1, 均線平均週期, 0, 均線平均方法, 均線使用價格);
   handle_ma2 = iMA(Symbol(), TimeFrame2, 均線平均週期, 0, 均線平均方法, 均線使用價格);
   handle_ma3 = iMA(Symbol(), TimeFrame3, 均線平均週期, 0, 均線平均方法, 均線使用價格);

   handle_bands1 = iBands(Symbol(), TimeFrame1, 布林平均週期, 0, 布林偏差值, 布林使用價格);
   handle_bands2 = iBands(Symbol(), TimeFrame2, 布林平均週期, 0, 布林偏差值, 布林使用價格);
   handle_bands3 = iBands(Symbol(), TimeFrame3, 布林平均週期, 0, 布林偏差值, 布林使用價格);

   if(handle_ma1 == INVALID_HANDLE || handle_ma2 == INVALID_HANDLE || handle_ma3 == INVALID_HANDLE ||
      handle_bands1 == INVALID_HANDLE || handle_bands2 == INVALID_HANDLE || handle_bands3 == INVALID_HANDLE)
     {
      Print("初始化指標 Handle 失敗！");
      return(INIT_FAILED);
     }
     
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
   iTradingSignals();
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
   ArraySetAsSeries(SignalBuffer, true);
   
   int signal = iTradingSignals();
   if(rates_total > 0)
     {
      SignalBuffer[0] = signal;
     }

   return(rates_total);
  }

int iTradingSignals()
  {
   int myReturnSignal = 9, my3M1Value = -1, my3M5Value = -1, my3M30Value = -1;
   color my3M1Color = clrDarkGray, my3M5Color = clrDarkGray, my3M30Color = clrDarkGray;

   double ma1[1], ma2[1], ma3[1];
   double bands1[1], bands2[1], bands3[1];

   if(CopyBuffer(handle_ma1, 0, 0, 1, ma1) <= 0) return 9;
   if(CopyBuffer(handle_ma2, 0, 0, 1, ma2) <= 0) return 9;
   if(CopyBuffer(handle_ma3, 0, 0, 1, ma3) <= 0) return 9;

   if(CopyBuffer(handle_bands1, BASE_LINE, 0, 1, bands1) <= 0) return 9;
   if(CopyBuffer(handle_bands2, BASE_LINE, 0, 1, bands2) <= 0) return 9;
   if(CopyBuffer(handle_bands3, BASE_LINE, 0, 1, bands3) <= 0) return 9;

   // 比較移動平均線和布林帶的主線 (BASE_LINE)
   if (ma1[0] > bands1[0]) { my3M1Value = 0; my3M1Color = clrGreen; }
   if (ma1[0] < bands1[0]) { my3M1Value = 1; my3M1Color = clrRed; }

   if (ma2[0] > bands2[0]) { my3M5Value = 0; my3M5Color = clrGreen; }
   if (ma2[0] < bands2[0]) { my3M5Value = 1; my3M5Color = clrRed; }

   if (ma3[0] > bands3[0]) { my3M30Value = 0; my3M30Color = clrGreen; }
   if (ma3[0] < bands3[0]) { my3M30Value = 1; my3M30Color = clrRed; }

   // 顯示各個時間框架的指標狀態
   iDisplayInfo("3M1", Frame1, 1, 10, 175, 8, "", clrDarkGray);
   iDisplayInfo("3M5", Frame2, 1, 30, 175, 8, "", clrDarkGray);
   iDisplayInfo("3M30", Frame3, 1, 50, 175, 8, "", clrDarkGray);
   iDisplayInfo("3MStatus", "狀態", 1, 80, 175, 9, "", clrDarkGray);

   iDisplayInfo("3M1v", IntegerToString(my3M1Value), 1, 15, 190, 10, "", my3M1Color);
   iDisplayInfo("3M5v", IntegerToString(my3M5Value), 1, 35, 190, 10, "", my3M5Color);
   iDisplayInfo("3M30v", IntegerToString(my3M30Value), 1, 55, 190, 10, "", my3M30Color);

   // 根據各個時間框架的信號值判斷市場狀態
   if (my3M5Value == 0 && my3M30Value == 0)
      iDisplayInfo("3MStatusValue", "趨多", 1, 80, 190, 9, "", clrGreen);
   if (my3M5Value == 1 && my3M30Value == 1)
      iDisplayInfo("3MStatusValue", "趨空", 1, 80, 190, 9, "", clrRed);
   if ((my3M5Value == 0 && my3M30Value == 1) || (my3M5Value == 1 && my3M30Value == 0))
      iDisplayInfo("3MStatusValue", "震盪", 1, 80, 190, 9, "", clrDarkGray);

   if (my3M30Value == 0 && my3M5Value == 0 && my3M1Value == 0)
     {
      iDisplayInfo("3MStatusInfo", "趨多加倉", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 0;
     }
   else if (my3M30Value == 0 && my3M5Value == 0 && my3M1Value == 1)
     {
      iDisplayInfo("3MStatusInfo", "趨多減倉", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 1;
     }
   else if (my3M30Value == 0 && my3M5Value == 1 && my3M1Value == 0)
     {
      iDisplayInfo("3MStatusInfo", "震盪多頭", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 2;
     }
   else if (my3M30Value == 1 && my3M5Value == 0 && my3M1Value == 0)
     {
      iDisplayInfo("3MStatusInfo", "震盪多頭", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 3;
     }
   else if (my3M30Value == 1 && my3M5Value == 1 && my3M1Value == 1)
     {
      iDisplayInfo("3MStatusInfo", "趨空加倉", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 4;
     }
   else if (my3M30Value == 1 && my3M5Value == 1 && my3M1Value == 0)
     {
      iDisplayInfo("3MStatusInfo", "趨空減倉", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 5;
     }
   else if (my3M30Value == 1 && my3M5Value == 0 && my3M1Value == 1)
     {
      iDisplayInfo("3MStatusInfo", "震盪空頭", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 6;
     }
   else if (my3M30Value == 0 && my3M5Value == 1 && my3M1Value == 1)
     {
      iDisplayInfo("3MStatusInfo", "震盪空頭", 1, 10, 205, 9, "", clrOlive);
      myReturnSignal = 7;
     }
   else
     {
      iDisplayInfo("3MStatusInfo", "等待信號", 1, 10, 205, 9, "", clrOlive);
     }

   return(myReturnSignal);
  }

void iDisplayInfo(string LableName, string LableDoc, int CornerPos, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   if (CornerPos == -1) return;
   
   int myWindowsHandle = ChartWindowFind();
   if(myWindowsHandle < 0) myWindowsHandle = 0;

   ObjectCreate(0, LableName, OBJ_LABEL, myWindowsHandle, 0, 0);
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   if(DocStyle != "") ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
   ObjectSetInteger(0, LableName, OBJPROP_CORNER, CornerPos);
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
  }
