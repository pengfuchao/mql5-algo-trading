//+------------------------------------------------------------------+
//|                                               Util_Doji_Line.mq5 |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- plot Cross
#property indicator_label1  "十字星價位"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- indicator buffers
double         Cross_Buffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- indicator buffers mapping
   SetIndexBuffer(0, Cross_Buffer, INDICATOR_DATA);
   ArrayInitialize(Cross_Buffer, 0.0);
   
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
   // MT5 陣列預設是由舊到新 (index 0 是最舊的資料)
   // 如果需要像 MT4 一樣從最新的 K 線 (index 0) 往回找，需設置 ArraySetAsSeries
   // 但標準做法是直接照迴圈處理：
   
   int limit = 0;
   if(prev_calculated == 0)
      limit = 0;
   else
      limit = prev_calculated - 1;
      
   for(int i = limit; i < rates_total; i++)
     {
      //---- 判斷蠟燭類型
      if(close[i] == open[i]) 
         Cross_Buffer[i] = close[i]; // 如果收盤價等於開盤價，蠟燭為十字形
      else 
         Cross_Buffer[i] = 0.0; // 如果不是十字形，設置為0.0 (MT5 不會畫出 0.0 的連線，如果設為 DRAW_SECTION 的話)
     }
     
   return(rates_total);
  }
//+------------------------------------------------------------------+
