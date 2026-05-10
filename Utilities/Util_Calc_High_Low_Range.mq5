//+------------------------------------------------------------------+
//|                                     Util_Calc_High_Low_Range.mq5 |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "區間高位"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "區間低位"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

datetime StartHour = 0;
double High_Buffer[];
double Low_Buffer[];

datetime tempStartHour = 0, tempEndHour = 0;
int tempStartHourShift = 0, tempEndHourShift = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   SetIndexBuffer(0, High_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, Low_Buffer, INDICATOR_DATA);
   
   // MT5 預設緩衝區方向與 MT4 相反，為了相容舊寫法可設為 true，
   // 但標準作法是在 OnCalculate 內進行 ArraySetAsSeries。
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(High_Buffer, true);
   ArraySetAsSeries(Low_Buffer, true);

   int limit = 0;
   if (prev_calculated == 0)
      limit = rates_total - 1;
   else
      limit = rates_total - prev_calculated;

   //---- 以起始時間查找全天的最高/低點
   for (int i = 0; i <= limit && i < rates_total; i++)
     {
      iHighLowInterval(i, time, high, low, rates_total);
     }
     
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 計算高低區間                                                     |
//+------------------------------------------------------------------+
void iHighLowInterval(int myBarShift, const datetime &time[], const double &high[], const double &low[], int rates_total)
  {
   datetime myBarTime = time[myBarShift];
   
   MqlDateTime dt;
   TimeToStruct(myBarTime, dt);
   
   // 當前區間開始時間
   dt.hour = (int)StartHour;
   dt.min = 0;
   dt.sec = 0;
   datetime myStartHour = StructToTime(dt);
   
   // 當前區間結束時間
   datetime myEndHour = myStartHour + 24 * 60 * 60; 

   if (tempStartHour != myStartHour || tempEndHour != myEndHour)
     {
      tempStartHour = myStartHour;
      tempEndHour = myEndHour;
      
      tempStartHourShift = iBarShift(Symbol(), PERIOD_CURRENT, tempStartHour);
      tempEndHourShift = iBarShift(Symbol(), PERIOD_CURRENT, tempEndHour);
      
      if(tempStartHourShift < 0) tempStartHourShift = 0;
      if(tempEndHourShift < 0) tempEndHourShift = 0;
      
      int tempBars = tempStartHourShift - tempEndHourShift; // 區間蠟燭數量
      
      if(tempBars <= 0) return;

      // 計算區間內高低點
      int myHightBar = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, tempBars, tempEndHourShift);
      int myLowBar = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, tempBars, tempEndHourShift);
      
      double myHightPrice = 0, myLowPrice = 0;
      if(myHightBar >= 0 && myHightBar < rates_total) myHightPrice = high[myHightBar];
      if(myLowBar >= 0 && myLowBar < rates_total) myLowPrice = low[myLowBar];

      // 給蠟燭賦值
      for (int cnt = 0; cnt <= tempBars; cnt++)
        {
         if(tempEndHourShift + cnt < rates_total)
           {
            High_Buffer[tempEndHourShift + cnt] = myHightPrice;
            Low_Buffer[tempEndHourShift + cnt] = myLowPrice;
           }
        }
     }
  }
