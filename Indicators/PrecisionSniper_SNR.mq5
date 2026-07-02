//+------------------------------------------------------------------+
//|                                  PrecisionSniper_SNR.mq5          |
//|                                                                  |
//|  Composite signal indicator: PrecisionSniper primary signal      |
//|  filtered by Support_Resistance_Channels nearest S/R levels.     |
//|                                                                  |
//|  EA-facing drop-in contract: Buffer 3 = filtered buy,             |
//|  Buffer 4 = filtered sell, matching PrecisionSniper.mq5.          |
//+------------------------------------------------------------------+
#property copyright "Composite wrapper for MT5 Strategy Library"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Raw Buy
#property indicator_label1  "RawBuy"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrPaleGreen
#property indicator_width1  1
//--- Raw Sell
#property indicator_label2  "RawSell"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLightCoral
#property indicator_width2  1
//--- Nearest Resistance
#property indicator_label3  "NearestRes"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrTomato
#property indicator_width3  1
//--- Filtered Buy
#property indicator_label4  "FilteredBuy"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  3
//--- Filtered Sell
#property indicator_label5  "FilteredSell"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  3
//--- Nearest Support
#property indicator_label6  "NearestSup"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrDodgerBlue
#property indicator_width6  1
//--- Blocked Buy
#property indicator_label7  "BlockedBuy"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrGold
#property indicator_width7  2
//--- Blocked Sell
#property indicator_label8  "BlockedSell"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrOrange
#property indicator_width8  2

//+------------------------------------------------------------------+
//| Enums mirrored from the upstream indicators                       |
//+------------------------------------------------------------------+
enum ENUM_PRESET
  {
   PRESET_AUTO         = 0,
   PRESET_SCALPING     = 1,
   PRESET_AGGRESSIVE   = 2,
   PRESET_DEFAULT      = 3,
   PRESET_CONSERVATIVE = 4,
   PRESET_SWING        = 5,
   PRESET_CRYPTO       = 6,
   PRESET_GOLD         = 7,
   PRESET_CUSTOM       = 8
  };

enum ENUM_GRADE_FILTER
  {
   GRADE_ALL      = 0,
   GRADE_A_PLUS_A = 1,
   GRADE_A_PLUS   = 2
  };

enum ENUM_SR_SOURCE
  {
   SRC_HIGHLOW   = 0,
   SRC_CLOSEOPEN = 1
  };

enum ENUM_SR_WIDTH_MODE
  {
   WIDTH_RANGE_PCT = 0,
   WIDTH_ATR       = 1
  };

enum ENUM_SNR_FILTER_MODE
  {
   SNR_BLOCK_ONLY   = 0,
   SNR_CONFIRMATION = 1
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "PS"
input ENUM_PRESET       Preset      = PRESET_DEFAULT;
input ENUM_TIMEFRAMES   HTF         = PERIOD_CURRENT;
input int               C_EmaFast   = 9;
input int               C_EmaSlow   = 21;
input int               C_EmaTrend  = 55;
input int               C_RSI       = 13;
input int               C_ATR       = 14;
input int               C_MinScore  = 5;
input double            C_SLMult    = 1.5;
input double            TP1_RR      = 1.0;
input double            TP2_RR      = 2.0;
input double            TP3_RR      = 3.0;
input double            SLMult      = 1.5;
input int               CooldownBars= 5;
input bool              UseTrail    = true;
input bool              StructureSL = true;
input int               SwingLB     = 10;
input ENUM_GRADE_FILTER GradeFilter = GRADE_ALL;
input bool              HideCGrade  = true;

input group "SNR"
input int                SNRPivotPeriod       = 10;
input ENUM_SR_SOURCE     SNRSourceMode        = SRC_HIGHLOW;
input int                SNRChannelWidthPct   = 2;
input int                SNRMinStrength       = 1;
input int                SNRMaxNumSR          = 3;
input int                SNRLoopback          = 290;
input ENUM_SR_WIDTH_MODE SNRChannelWidthMode  = WIDTH_RANGE_PCT;
input int                SNRATRLen            = 14;
input double             SNRATRMult           = 0.3;
input bool               SNRUseVolumeFilter   = false;
input int                SNRVolMaLen          = 20;
input double             SNRVolMult           = 1.0;
input double             SNRRetestTolerATR    = 0.10;
input int                SNRRetestExpiryBars  = 20;

input group "Filter"
input ENUM_SNR_FILTER_MODE SNRMode            = SNR_BLOCK_ONLY;
input double               BlockDistanceATR   = 0.3;
input double               ConfirmDistanceATR = 1.0;

input group "Display"
input bool ShowRaw     = true;
input bool ShowBlocked = true;
input bool ShowLevels  = false;

//+------------------------------------------------------------------+
//| Buffers                                                          |
//+------------------------------------------------------------------+
double bufRawBuy[];
double bufRawSell[];
double bufNearestRes[];
double bufFilteredBuy[];
double bufFilteredSell[];
double bufNearestSup[];
double bufBlockedBuy[];
double bufBlockedSell[];

int hPS  = INVALID_HANDLE;
int hSNR = INVALID_HANDLE;
int hATR = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, bufRawBuy,       INDICATOR_DATA);
   SetIndexBuffer(1, bufRawSell,      INDICATOR_DATA);
   SetIndexBuffer(2, bufNearestRes,   INDICATOR_DATA);
   SetIndexBuffer(3, bufFilteredBuy,  INDICATOR_DATA);
   SetIndexBuffer(4, bufFilteredSell, INDICATOR_DATA);
   SetIndexBuffer(5, bufNearestSup,   INDICATOR_DATA);
   SetIndexBuffer(6, bufBlockedBuy,   INDICATOR_DATA);
   SetIndexBuffer(7, bufBlockedSell,  INDICATOR_DATA);

   ArraySetAsSeries(bufRawBuy,       true);
   ArraySetAsSeries(bufRawSell,      true);
   ArraySetAsSeries(bufNearestRes,   true);
   ArraySetAsSeries(bufFilteredBuy,  true);
   ArraySetAsSeries(bufFilteredSell, true);
   ArraySetAsSeries(bufNearestSup,   true);
   ArraySetAsSeries(bufBlockedBuy,   true);
   ArraySetAsSeries(bufBlockedSell,  true);

   for(int p = 0; p < 8; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, 0.0);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetInteger(6, PLOT_ARROW, 251);
   PlotIndexSetInteger(7, PLOT_ARROW, 251);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT,  20);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, -15);
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT,  15);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, ShowRaw ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, ShowRaw ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, ShowLevels ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, ShowLevels ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, ShowBlocked ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, ShowBlocked ? DRAW_ARROW : DRAW_NONE);

   hPS = iCustom(_Symbol, PERIOD_CURRENT, "PrecisionSniper",
                 Preset, HTF, C_EmaFast, C_EmaSlow, C_EmaTrend, C_RSI, C_ATR, C_MinScore, C_SLMult,
                 TP1_RR, TP2_RR, TP3_RR, SLMult, CooldownBars, UseTrail, StructureSL, SwingLB,
                 GradeFilter, HideCGrade,
                 true, false, false, false, false,
                 0, D'2025.01.01 00:00', D'2025.12.31 23:59', 500);

   hSNR = iCustom(_Symbol, PERIOD_CURRENT, "Support_Resistance_Channels",
                  SNRPivotPeriod, SNRSourceMode, SNRChannelWidthPct, SNRMinStrength, SNRMaxNumSR, SNRLoopback,
                  SNRChannelWidthMode, SNRATRLen, SNRATRMult, SNRUseVolumeFilter, SNRVolMaLen, SNRVolMult,
                  SNRRetestTolerATR, SNRRetestExpiryBars);

   hATR = iATR(_Symbol, PERIOD_CURRENT, MathMax(1, C_ATR));

   if(hPS == INVALID_HANDLE || hSNR == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      PrintFormat("PrecisionSniper_SNR: handle init failed ps=%d snr=%d atr=%d error=%d",
                  hPS, hSNR, hATR, GetLastError());
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, "PrecisionSniper_SNR");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hPS  != INVALID_HANDLE) IndicatorRelease(hPS);
   if(hSNR != INVALID_HANDLE) IndicatorRelease(hSNR);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
  }

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
   if(rates_total < 3)
      return(0);
   if(BarsCalculated(hPS) < 2 || BarsCalculated(hSNR) < 2 || BarsCalculated(hATR) < 2)
      return(prev_calculated);

   ArraySetAsSeries(close, true);

   double psBuy[], psSell[], nearRes[], nearSup[], atr[];
   ArraySetAsSeries(psBuy,   true);
   ArraySetAsSeries(psSell,  true);
   ArraySetAsSeries(nearRes, true);
   ArraySetAsSeries(nearSup, true);
   ArraySetAsSeries(atr,     true);

   int c1 = CopyBuffer(hPS,  3, 0, rates_total, psBuy);
   int c2 = CopyBuffer(hPS,  4, 0, rates_total, psSell);
   int c3 = CopyBuffer(hSNR, 4, 0, rates_total, nearRes);
   int c4 = CopyBuffer(hSNR, 5, 0, rates_total, nearSup);
   int c5 = CopyBuffer(hATR, 0, 0, rates_total, atr);
   if(c1 <= 0 || c2 <= 0 || c3 <= 0 || c4 <= 0 || c5 <= 0)
      return(prev_calculated);

   int limit = MathMin(rates_total, MathMin(c1, MathMin(c2, MathMin(c3, MathMin(c4, c5)))));

   // Incremental recompute: only refresh the newest changed bars (series index 0..).
   // prev_calculated==0 (or history refresh) -> full recompute of the valid region.
   // Same-bar tick -> recompute only the forming bar (index 0); already-closed bars
   // stay frozen, which matches the EA's causal shift=1 consumption and reduces the
   // historical display repaint caused by the upstream rolling S/R loopback window.
   int recalc = (prev_calculated > 1) ? (rates_total - prev_calculated + 1) : rates_total;
   if(recalc > limit)
      recalc = limit;

   for(int i = 0; i < recalc; i++)
     {
      double rawBuy  = psBuy[i];
      double rawSell = psSell[i];
      double res     = nearRes[i];
      double sup     = nearSup[i];
      double atrVal  = atr[i];
      double cls     = close[i];

      bufRawBuy[i]       = rawBuy;
      bufRawSell[i]      = rawSell;
      bufNearestRes[i]   = res;
      bufNearestSup[i]   = sup;
      bufFilteredBuy[i]  = 0.0;
      bufFilteredSell[i] = 0.0;
      bufBlockedBuy[i]   = 0.0;
      bufBlockedSell[i]  = 0.0;

      if(atrVal <= 0.0)
        {
         bufFilteredBuy[i]  = rawBuy;
         bufFilteredSell[i] = rawSell;
         continue;
        }

      double distRes = (res > 0.0) ? MathAbs(res - cls) : DBL_MAX;
      double distSup = (sup > 0.0) ? MathAbs(cls - sup) : DBL_MAX;

      bool nearResBlock = (res > 0.0 && distRes <= atrVal * BlockDistanceATR);
      bool nearSupBlock = (sup > 0.0 && distSup <= atrVal * BlockDistanceATR);

      if(SNRMode == SNR_BLOCK_ONLY)
        {
         bufFilteredBuy[i]  = (rawBuy  > 0.0 && !nearResBlock) ? rawBuy  : 0.0;
         bufFilteredSell[i] = (rawSell > 0.0 && !nearSupBlock) ? rawSell : 0.0;
        }
      else
        {
         bool nearSupConfirm = (sup > 0.0 && distSup <= atrVal * ConfirmDistanceATR);
         bool nearResConfirm = (res > 0.0 && distRes <= atrVal * ConfirmDistanceATR);
         bufFilteredBuy[i]  = (rawBuy  > 0.0 && nearSupConfirm && !nearResBlock) ? rawBuy  : 0.0;
         bufFilteredSell[i] = (rawSell > 0.0 && nearResConfirm && !nearSupBlock) ? rawSell : 0.0;
        }

      bufBlockedBuy[i]  = (rawBuy  > 0.0 && bufFilteredBuy[i]  == 0.0) ? rawBuy  : 0.0;
      bufBlockedSell[i] = (rawSell > 0.0 && bufFilteredSell[i] == 0.0) ? rawSell : 0.0;
     }

   for(int i = limit; i < rates_total; i++)
     {
      bufRawBuy[i] = 0.0;
      bufRawSell[i] = 0.0;
      bufNearestRes[i] = 0.0;
      bufFilteredBuy[i] = 0.0;
      bufFilteredSell[i] = 0.0;
      bufNearestSup[i] = 0.0;
      bufBlockedBuy[i] = 0.0;
      bufBlockedSell[i] = 0.0;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
