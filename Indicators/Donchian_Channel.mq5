//+------------------------------------------------------------------+
//|                                             Donchian_Channel.mq5 |
//+------------------------------------------------------------------+

//---- indicator settings
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_width1  1

#property indicator_label2  "Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_width2  1

//---- indicator parameters
input int periods = 20;            

//---- indicator buffers
double upper[];
double lower[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, upper, INDICATOR_DATA);
   SetIndexBuffer(1, lower, INDICATOR_DATA);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Donchian Channel(" + IntegerToString(periods) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
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
   // 若無足夠 K 線，提早返回
   if(rates_total < periods) return(0);

   // 設定為 Series 結構 (索引 0 為最新 K 線)
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   // 計算需要更新的起始位置
   int limit = rates_total - prev_calculated;
   if(prev_calculated > 0) limit++; // 重算上一根以避免漏算
   if(limit >= rates_total) limit = rates_total - periods; // 首次計算，保留足夠的週期數量

   for(int i = limit - 1; i >= 0; i--)
     {
      // 尋找最高點與最低點的索引 (注意：MT5 ArrayMaximum/ArrayMinimum 參數為 start_index, count)
      int highest_idx = ArrayMaximum(high, i, periods);
      int lowest_idx = ArrayMinimum(low, i, periods);
      
      if(highest_idx >= 0 && lowest_idx >= 0)
        {
         upper[i] = high[highest_idx];
         lower[i] = low[lowest_idx];
        }
     }
   
   return(rates_total);
  }
