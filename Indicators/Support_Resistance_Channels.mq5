//+------------------------------------------------------------------+
//|                                 Support_Resistance_Channels.mq5   |
//|                                                                  |
//|  MQL5 port of "Support Resistance Channels" (SRchannel)          |
//|  Original Pine Script v6 © LonesomeTheBlue (MPL-2.0)             |
//|                                                                  |
//|  以樞紐點 (Pivot) 分群建立支撐/壓力「通道」，依強度挑選最強的      |
//|  數條通道並以矩形繪製；價格突破或影線拒絕通道時可標記並提示。     |
//+------------------------------------------------------------------+
#property copyright "Pine original © LonesomeTheBlue (MPL-2.0); MQL5 port"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- MA1
#property indicator_label1  "MA1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
//--- MA2
#property indicator_label2  "MA2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  1
//--- 以下為 EA 讀取用的資料 buffer (不繪圖)
//--- Buffer 2: Resistance Broken signal (突破當根收盤價，否則 0)
#property indicator_label3  "ResBroken"
#property indicator_type3   DRAW_NONE
//--- Buffer 3: Support Broken signal (跌破當根收盤價，否則 0)
#property indicator_label4  "SupBroken"
#property indicator_type4   DRAW_NONE
//--- Buffer 4: 現價上方最近通道下緣 (最近壓力位，否則 0)
#property indicator_label5  "NearestRes"
#property indicator_type5   DRAW_NONE
//--- Buffer 5: 現價下方最近通道上緣 (最近支撐位，否則 0)
#property indicator_label6  "NearestSup"
#property indicator_type6   DRAW_NONE
//--- Buffer 6: Resistance Bounce signal (壓力拒絕當根收盤價，否則 0)
#property indicator_label7  "ResBounce"
#property indicator_type7   DRAW_NONE
//--- Buffer 7: Support Bounce signal (支撐拒絕當根收盤價，否則 0)
#property indicator_label8  "SupBounce"
#property indicator_type8   DRAW_NONE

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
enum ENUM_SR_SOURCE
  {
   SRC_HIGHLOW = 0,   // High/Low
   SRC_CLOSEOPEN = 1  // Close/Open
  };

input group "Settings"
input int             PivotPeriod    = 10;             // Pivot Period (4-30)
input ENUM_SR_SOURCE  SourceMode     = SRC_HIGHLOW;    // Source for Pivot Points
input int             ChannelWidthPct= 5;              // Max Channel Width % (1-8)
input int             MinStrength    = 1;              // Minimum Strength (>=1)
input int             MaxNumSR       = 6;              // Maximum Number of S/R (1-10)
input int             Loopback       = 290;            // Loopback Period (100-400)

input group "Colors"
input color           ResColor       = clrTomato;      // Resistance color (price below channel)
input color           SupColor       = clrLime;        // Support color (price above channel)
input color           InChColor      = clrGray;        // Color when price in channel

input group "Extras"
input bool            ShowPivot      = false;          // Show Pivot Points
input bool            ShowBroken     = false;          // Show Broken Support/Resistance
input bool            ShowBounce     = false;          // Show Bounce Support/Resistance
input bool            AlertsOn       = false;          // Enable S/R alerts

input group "Moving Average 1"
input bool            MA1On          = false;          // MA 1 enable
input int             MA1Len         = 50;             // MA 1 length
input ENUM_MA_METHOD  MA1Type        = MODE_SMA;       // MA 1 type (SMA/EMA)

input group "Moving Average 2"
input bool            MA2On          = false;          // MA 2 enable
input int             MA2Len         = 200;            // MA 2 length
input ENUM_MA_METHOD  MA2Type        = MODE_SMA;       // MA 2 type (SMA/EMA)

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
double  bufMA1[];
double  bufMA2[];
double  bufResBrk[];   // Buffer 2: 壓力突破訊號
double  bufSupBrk[];   // Buffer 3: 支撐跌破訊號
double  bufNearRes[];  // Buffer 4: 最近壓力位
double  bufNearSup[];  // Buffer 5: 最近支撐位
double  bufResBounce[];// Buffer 6: 壓力拒絕反彈訊號
double  bufSupBounce[];// Buffer 7: 支撐拒絕反彈訊號

double  SR[20];        // 已選出的通道 (top,bottom) 配對，最多 10 條
double  SRStren[10];   // 對應通道強度

int     handleMA1 = INVALID_HANDLE;
int     handleMA2 = INVALID_HANDLE;

datetime g_lastBar = 0;

const string PFX    = "SRchan_";       // 通道矩形物件前綴
const string PFXPP  = "SRchan_pp_";    // 樞紐點標籤前綴
const string PFXBK  = "SRchan_brk_";   // 突破標記前綴
const string PFXBO  = "SRchan_bnc_";   // 反彈標記前綴

//--- 經輸入驗證後的有效參數
int g_prd, g_chw, g_minstr, g_maxsr, g_loopback;

//+------------------------------------------------------------------+
//| 初始化                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 驗證並夾限輸入 (對齊 Pine minval/maxval)
   g_prd      = (int)MathMax(4,   MathMin(30, PivotPeriod));
   g_chw      = (int)MathMax(1,   MathMin(8,  ChannelWidthPct));
   g_minstr   = (int)MathMax(1,   MinStrength);
   g_maxsr    = (int)MathMax(1,   MathMin(10, MaxNumSR)) - 1; // Pine: 輸入值 - 1
   g_loopback = (int)MathMax(100, MathMin(400, Loopback));

   SetIndexBuffer(0, bufMA1,     INDICATOR_DATA);
   SetIndexBuffer(1, bufMA2,     INDICATOR_DATA);
   SetIndexBuffer(2, bufResBrk,  INDICATOR_DATA);
   SetIndexBuffer(3, bufSupBrk,  INDICATOR_DATA);
   SetIndexBuffer(4, bufNearRes, INDICATOR_DATA);
   SetIndexBuffer(5, bufNearSup, INDICATOR_DATA);
   SetIndexBuffer(6, bufResBounce, INDICATOR_DATA);
   SetIndexBuffer(7, bufSupBounce, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(bufMA1,     true);
   ArraySetAsSeries(bufMA2,     true);
   ArraySetAsSeries(bufResBrk,  true);
   ArraySetAsSeries(bufSupBrk,  true);
   ArraySetAsSeries(bufNearRes, true);
   ArraySetAsSeries(bufNearSup, true);
   ArraySetAsSeries(bufResBounce, true);
   ArraySetAsSeries(bufSupBounce, true);

//--- 建立 MA handle (只在啟用時建立)
   if(MA1On)
     {
      handleMA1 = iMA(_Symbol, _Period, MathMax(1, MA1Len), 0, MA1Type, PRICE_CLOSE);
      if(handleMA1 == INVALID_HANDLE)
         Print("SRchannel: 建立 MA1 handle 失敗, error=", GetLastError());
     }
   if(MA2On)
     {
      handleMA2 = iMA(_Symbol, _Period, MathMax(1, MA2Len), 0, MA2Type, PRICE_CLOSE);
      if(handleMA2 == INVALID_HANDLE)
         Print("SRchannel: 建立 MA2 handle 失敗, error=", GetLastError());
     }

   ArrayInitialize(SR, 0.0);
   ArrayInitialize(SRStren, 0.0);
   g_lastBar = 0;

   IndicatorSetString(INDICATOR_SHORTNAME, "SRchannel(" + IntegerToString(g_prd) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| 反初始化                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(handleMA1 != INVALID_HANDLE) IndicatorRelease(handleMA1);
   if(handleMA2 != INVALID_HANDLE) IndicatorRelease(handleMA2);

//--- 清除所有本指標建立的圖表物件
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| 主計算                                                           |
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
   const int minBars = g_prd * 2 + 10;
   if(rates_total < minBars)
      return(0);

//--- 全部以 Series 結構處理 (索引 0 = 最新 K 棒)
   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

//--- 更新 MA 線
   UpdateMA(handleMA1, bufMA1, rates_total);
   UpdateMA(handleMA2, bufMA2, rates_total);

//--- 僅在新 K 棒 (或首次載入) 重算 S/R，避免盤中 repaint
   bool firstRun = (prev_calculated == 0) || (g_lastBar == 0);
   bool newBar   = (time[0] != g_lastBar);
   if(firstRun)
     {
      // 訊號 buffer 僅在首次計算或歷史刷新時整段歸零，之後逐棒寫入
      ArrayInitialize(bufResBrk,  0.0);
      ArrayInitialize(bufSupBrk,  0.0);
      ArrayInitialize(bufNearRes, 0.0);
      ArrayInitialize(bufNearSup, 0.0);
      ArrayInitialize(bufResBounce, 0.0);
      ArrayInitialize(bufSupBounce, 0.0);
     }
   if(firstRun || newBar)
     {
      ComputeSR(time, open, high, low, close, rates_total);
      RedrawChannels(time, close, rates_total);
      RedrawPivots(time, rates_total);
      UpdateSignals(time, high, low, close, rates_total);
      g_lastBar = time[0];
      ChartRedraw();
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 更新單條 MA buffer                                               |
//+------------------------------------------------------------------+
void UpdateMA(const int handle, double &buf[], const int rates_total)
  {
   if(handle == INVALID_HANDLE)
     {
      ArrayInitialize(buf, EMPTY_VALUE);
      return;
     }
   if(CopyBuffer(handle, 0, 0, rates_total, buf) <= 0)
      ArrayInitialize(buf, EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//| 重新計算支撐/壓力通道 (對應 Pine 主邏輯)                         |
//+------------------------------------------------------------------+
void ComputeSR(const datetime &time[],
               const double &open[],
               const double &high[],
               const double &low[],
               const double &close[],
               const int rates_total)
  {
   int lb = MathMin(g_loopback, rates_total - 1);

//--- 樞紐點來源序列 (依 Source 設定)
//    need 需容納至 shift = loopback + prd 的 pivot 中心，其右側鄰居延伸至 loopback + 2*prd，
//    故長度取 loopback + 2*prd + 2，避免漏掉最舊約 (prd-1) 根仍在 Loopback 內的有效 pivot。
   int need = MathMin(rates_total, g_loopback + 2 * g_prd + 2);
   double srcH[], srcL[];
   ArrayResize(srcH, need);
   ArrayResize(srcL, need);
   for(int i = 0; i < need; i++)
     {
      if(SourceMode == SRC_HIGHLOW)
        {
         srcH[i] = high[i];
         srcL[i] = low[i];
        }
      else
        {
         srcH[i] = MathMax(close[i], open[i]);
         srcL[i] = MathMin(close[i], open[i]);
        }
     }

//--- 收集 loopback 範圍內的樞紐點 (索引 0 = 最新樞紐，對齊 Pine unshift 順序)
   double pv[];     // 樞紐值
   int    ptype[];  // 1 = pivot high, -1 = pivot low
   int    ploc[];   // 樞紐 K 棒的 shift
   ArrayResize(pv, 0);
   ArrayResize(ptype, 0);
   ArrayResize(ploc, 0);

   // 因果性：以已收盤棒 (shift>=1) 為基準計算，最近的 pivot 右側不得用到形成中棒 bar0，
   //          故 pivot 偵測自 i = g_prd + 1 起 (鄰居 k 最小為 shift 1)。
   int hiBound = MathMin(lb + g_prd, need - 1 - g_prd);
   for(int i = g_prd + 1; i <= hiBound; i++)
     {
      bool isPH = true, isPL = true;
      double vh = srcH[i];
      double vl = srcL[i];
      for(int k = i - g_prd; k <= i + g_prd; k++)
        {
         if(k == i) continue;
         if(srcH[k] >= vh) isPH = false;   // 左右兩側皆嚴格較小才算 pivot high
         if(srcL[k] <= vl) isPL = false;   // 左右兩側皆嚴格較大才算 pivot low
        }
      if(isPH)
        {
         AppendPivot(pv, ptype, ploc, vh, 1, i);
        }
      else if(isPL)
        {
         AppendPivot(pv, ptype, ploc, vl, -1, i);
        }
     }

   int npv = ArraySize(pv);

//--- 重設輸出
   ArrayInitialize(SR, 0.0);
   ArrayInitialize(SRStren, 0.0);
   if(npv == 0)
      return;

//--- 通道最大寬度 = 近 300 棒 (highest-lowest) * ChannelW% (自 shift 1 起，排除形成中棒)
   int n300 = MathMin(300, rates_total - 1);
   int hidx = ArrayMaximum(high, 1, n300);
   int lidx = ArrayMinimum(low, 1, n300);
   double cwidth = 0.0;
   if(hidx >= 0 && lidx >= 0)
      cwidth = (high[hidx] - low[lidx]) * g_chw / 100.0;

//--- 對每個樞紐求其通道 (hi/lo) 與初始強度 (每納入一個樞紐 +20)
   double sHi[], sLo[], sStr[];
   ArrayResize(sHi, npv);
   ArrayResize(sLo, npv);
   ArrayResize(sStr, npv);
   for(int x = 0; x < npv; x++)
     {
      double hi = pv[x];
      double lo = pv[x];
      int numpp = 0;
      for(int y = 0; y < npv; y++)
        {
         double cpp  = pv[y];
         double wdth = (cpp <= hi) ? (hi - cpp) : (cpp - lo);
         if(wdth <= cwidth)
           {
            if(cpp <= hi) lo = MathMin(lo, cpp);
            else          hi = MathMax(hi, cpp);
            numpp += 20;
           }
        }
      sHi[x]  = hi;
      sLo[x]  = lo;
      sStr[x] = numpp;
     }

//--- 對每個通道，統計 loopback 內有多少 K 棒之 high 或 low 落於通道
   for(int x = 0; x < npv; x++)
     {
      double h = sHi[x];
      double l = sLo[x];
      int s = 0;
      for(int y = 1; y <= lb; y++)   // 自 shift 1 起，排除形成中棒 bar0 (因果性)
        {
         if((high[y] <= h && high[y] >= l) || (low[y] <= h && low[y] >= l))
            s++;
        }
      sStr[x] += s;
     }

//--- 依強度挑出最強且互不重疊的通道 (最多 10 條)
   int src = 0;
   for(int x = 0; x < npv; x++)
     {
      double stv = -1.0;
      int    stl = -1;
      for(int y = 0; y < npv; y++)
        {
         if(sStr[y] > stv && sStr[y] >= g_minstr * 20)
           {
            stv = sStr[y];
            stl = y;
           }
        }
      if(stl < 0)
         break;

      double hh = sHi[stl];
      double ll = sLo[stl];
      SR[src * 2]     = hh;
      SR[src * 2 + 1] = ll;
      SRStren[src]    = sStr[stl];

      // 將被涵蓋的樞紐強度設為 -1，避免重複選取相鄰通道
      for(int y = 0; y < npv; y++)
        {
         if((sHi[y] <= hh && sHi[y] >= ll) || (sLo[y] <= hh && sLo[y] >= ll))
            sStr[y] = -1;
        }

      src++;
      if(src >= 10)
         break;
     }

//--- 依強度由大到小排序 (顯示順序；不影響顯示集合)
   for(int x = 0; x < 9; x++)
      for(int y = x + 1; y < 10; y++)
        {
         if(SRStren[y] > SRStren[x])
           {
            double t = SRStren[y]; SRStren[y] = SRStren[x]; SRStren[x] = t;
            t = SR[y * 2];     SR[y * 2]     = SR[x * 2];     SR[x * 2]     = t;
            t = SR[y * 2 + 1]; SR[y * 2 + 1] = SR[x * 2 + 1]; SR[x * 2 + 1] = t;
           }
        }
  }

//+------------------------------------------------------------------+
//| 將樞紐點追加至陣列尾端                                           |
//+------------------------------------------------------------------+
void AppendPivot(double &pv[], int &ptype[], int &ploc[],
                 const double val, const int type, const int loc)
  {
   int n = ArraySize(pv);
   ArrayResize(pv,    n + 1);
   ArrayResize(ptype, n + 1);
   ArrayResize(ploc,  n + 1);
   pv[n]    = val;
   ptype[n] = type;
   ploc[n]  = loc;
  }

//+------------------------------------------------------------------+
//| 依通道與現價決定顏色                                             |
//+------------------------------------------------------------------+
color ChannelColor(const double top, const double bottom, const double cls)
  {
   if(top > cls && bottom > cls)  return(ResColor);   // 價格在通道下方 → 壓力
   if(top < cls && bottom < cls)  return(SupColor);   // 價格在通道上方 → 支撐
   return(InChColor);                                 // 價格在通道內
  }

//+------------------------------------------------------------------+
//| 繪製通道矩形                                                     |
//+------------------------------------------------------------------+
void RedrawChannels(const datetime &time[], const double &close[], const int rates_total)
  {
   int leftIdx     = MathMin(rates_total - 1, g_loopback + g_prd);
   datetime tLeft  = time[leftIdx];
   datetime tRight = time[0] + (datetime)(PeriodSeconds() * 20); // 向右延伸模擬 extend.both
   double cls      = close[0];

   for(int x = 0; x < 10; x++)
     {
      string nm = PFX + "box" + IntegerToString(x);
      ObjectDelete(0, nm);

      if(x > g_maxsr)
         continue;

      double top    = SR[x * 2];
      double bottom = SR[x * 2 + 1];
      if(top == 0.0 && bottom == 0.0)
         continue;

      color col = ChannelColor(top, bottom, cls);

      if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0, tLeft, top, tRight, bottom))
        {
         ObjectSetInteger(0, nm, OBJPROP_COLOR, col);
         ObjectSetInteger(0, nm, OBJPROP_FILL, true);
         ObjectSetInteger(0, nm, OBJPROP_BACK, true);
         ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
        }
      else
        {
         ObjectSetInteger(0, nm, OBJPROP_COLOR, col);
         ObjectSetInteger(0, nm, OBJPROP_TIME, 0, tLeft);
         ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, top);
         ObjectSetInteger(0, nm, OBJPROP_TIME, 1, tRight);
         ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, bottom);
        }
     }
  }

//+------------------------------------------------------------------+
//| 繪製樞紐點標籤 (H/L)                                             |
//+------------------------------------------------------------------+
void RedrawPivots(const datetime &time[], const int rates_total)
  {
   ObjectsDeleteAll(0, PFXPP);
   if(!ShowPivot)
      return;

//--- 重新偵測一次樞紐 (與 ComputeSR 相同條件)，僅供標示
   int lb   = MathMin(g_loopback, rates_total - 1);
   int need = MathMin(rates_total, g_loopback + 2 * g_prd + 2);
   int hiBound = MathMin(lb + g_prd, need - 1 - g_prd);

   for(int i = g_prd + 1; i <= hiBound; i++)   // 與 ComputeSR 一致：自 shift 1 起
     {
      double vh, vl;
      if(SourceMode == SRC_HIGHLOW)
        { vh = iHigh(_Symbol, _Period, i); vl = iLow(_Symbol, _Period, i); }
      else
        {
         double c = iClose(_Symbol, _Period, i), o = iOpen(_Symbol, _Period, i);
         vh = MathMax(c, o); vl = MathMin(c, o);
        }
      bool isPH = true, isPL = true;
      for(int k = i - g_prd; k <= i + g_prd; k++)
        {
         if(k == i) continue;
         double kh, kl;
         if(SourceMode == SRC_HIGHLOW)
           { kh = iHigh(_Symbol, _Period, k); kl = iLow(_Symbol, _Period, k); }
         else
           {
            double c = iClose(_Symbol, _Period, k), o = iOpen(_Symbol, _Period, k);
            kh = MathMax(c, o); kl = MathMin(c, o);
           }
         if(kh >= vh) isPH = false;
         if(kl <= vl) isPL = false;
        }
      if(isPH)
         DrawPivotLabel(time[i], vh, true);
      else if(isPL)
         DrawPivotLabel(time[i], vl, false);
     }
  }

//+------------------------------------------------------------------+
//| 建立單個樞紐標籤                                                 |
//+------------------------------------------------------------------+
void DrawPivotLabel(const datetime t, const double price, const bool isHigh)
  {
   string nm = PFXPP + (string)(long)t;
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, price);
   ObjectSetString (0, nm, OBJPROP_TEXT, isHigh ? "H" : "L");
   ObjectSetInteger(0, nm, OBJPROP_COLOR, isHigh ? ResColor : SupColor);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| 更新訊號 buffer 與突破標記 (以「已收盤」K 棒 shift=1 為基準)      |
//|   - 突破判定使用 close[1] 相對 close[2]，寫入 buffer index 1，    |
//|     供 EA 以 shift=1 讀取已收盤狀態，避免盤中 repaint。           |
//|   - 最近壓力/支撐位同樣寫於 index 1。                             |
//+------------------------------------------------------------------+
void UpdateSignals(const datetime &time[],
                   const double &high[],
                   const double &low[],
                   const double &close[],
                   const int rates_total)
  {
   if(rates_total < 3)
      return;

   double cClosed = close[1];   // 剛收盤的 K 棒
   double cPrev   = close[2];   // 其前一根

//--- 最近壓力 (現價上方最近通道的下緣) 與最近支撐 (現價下方最近通道的上緣)
   double nearRes = 0.0, nearSup = 0.0;
   for(int x = 0; x <= g_maxsr; x++)
     {
      double top = SR[x * 2], bottom = SR[x * 2 + 1];
      if(top == 0.0 && bottom == 0.0) continue;
      if(bottom > cClosed)                                  // 通道整體在現價之上
        { if(nearRes == 0.0 || bottom < nearRes) nearRes = bottom; }
      if(top < cClosed)                                     // 通道整體在現價之下
        { if(nearSup == 0.0 || top > nearSup) nearSup = top; }
     }

//--- 現價是否落在任一通道內 (與 Pine not_in_a_channel 對齊)
   bool inChannel = false;
   for(int x = 0; x <= g_maxsr; x++)
     {
      double top = SR[x * 2], bottom = SR[x * 2 + 1];
      if(top == 0.0 && bottom == 0.0) continue;
      if(cClosed <= top && cClosed >= bottom) { inChannel = true; break; }
     }

   bool resBroken = false, supBroken = false;
   if(!inChannel)
     {
      for(int x = 0; x <= g_maxsr; x++)
        {
         double top = SR[x * 2], bottom = SR[x * 2 + 1];
         if(top == 0.0 && bottom == 0.0) continue;
         if(cPrev <= top && cClosed > top)        resBroken = true; // 向上突破壓力
         if(cPrev >= bottom && cClosed < bottom)  supBroken = true; // 向下跌破支撐
        }
     }

   bool resBounce = false, supBounce = false;
   for(int x = 0; x <= g_maxsr; x++)
     {
      double top = SR[x * 2], bottom = SR[x * 2 + 1];
      if(top == 0.0 && bottom == 0.0) continue;

      // 壓力拒絕：上一根收在通道下方，本根影線觸及/穿入壓力通道，收盤仍回到通道下方。
      if(cPrev < bottom && high[1] >= bottom && cClosed < bottom)
         resBounce = true;

      // 支撐拒絕：上一根收在通道上方，本根影線觸及/穿入支撐通道，收盤仍回到通道上方。
      if(cPrev > top && low[1] <= top && cClosed > top)
         supBounce = true;
     }

//--- 寫入 EA 讀取用 buffer (index 1 = 已收盤棒；index 0 = 形成中棒，突破暫為 0)
   bufResBrk[1]     = resBroken ? cClosed : 0.0;
   bufSupBrk[1]     = supBroken ? cClosed : 0.0;
   bufNearRes[1]    = nearRes;
   bufNearSup[1]    = nearSup;
   bufResBounce[1]  = resBounce ? cClosed : 0.0;
   bufSupBounce[1]  = supBounce ? cClosed : 0.0;
   bufResBrk[0]     = 0.0;
   bufSupBrk[0]     = 0.0;
   bufNearRes[0]    = nearRes;
   bufNearSup[0]    = nearSup;
   bufResBounce[0]  = 0.0;
   bufSupBounce[0]  = 0.0;

//--- 圖表標記與提示 (置於已收盤棒)
   if(ShowBroken && resBroken)
      DrawBrokenMarker(time[1], cClosed, true);
   if(ShowBroken && supBroken)
      DrawBrokenMarker(time[1], cClosed, false);
   if(ShowBounce && resBounce)
      DrawBounceMarker(time[1], high[1], true);
   if(ShowBounce && supBounce)
      DrawBounceMarker(time[1], low[1], false);

   if(AlertsOn && resBroken)
      Alert(_Symbol, " ", EnumToString(_Period), " SRchannel: Resistance Broken");
   if(AlertsOn && supBroken)
      Alert(_Symbol, " ", EnumToString(_Period), " SRchannel: Support Broken");
   if(AlertsOn && resBounce)
      Alert(_Symbol, " ", EnumToString(_Period), " SRchannel: Resistance Bounce");
   if(AlertsOn && supBounce)
      Alert(_Symbol, " ", EnumToString(_Period), " SRchannel: Support Bounce");
  }

//+------------------------------------------------------------------+
//| 建立突破標記箭頭                                                 |
//+------------------------------------------------------------------+
void DrawBrokenMarker(const datetime t, const double price, const bool resistance)
  {
   string nm = PFXBK + (resistance ? "res_" : "sup_") + (string)(long)t;
   if(ObjectFind(0, nm) >= 0)
      return;
   // 壓力突破 → 向上箭頭(241) 置於 K 棒下方；支撐跌破 → 向下箭頭(242) 置於上方
   ObjectCreate(0, nm, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, resistance ? 241 : 242);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, resistance ? SupColor : ResColor);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, resistance ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| 建立反彈標記箭頭                                                 |
//+------------------------------------------------------------------+
void DrawBounceMarker(const datetime t, const double price, const bool resistance)
  {
   string nm = PFXBO + (resistance ? "res_" : "sup_") + (string)(long)t;
   if(ObjectFind(0, nm) >= 0)
      return;
   // 壓力拒絕 → 向下箭頭；支撐拒絕 → 向上箭頭，標在觸及的影線附近。
   ObjectCreate(0, nm, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, resistance ? 242 : 241);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, resistance ? ResColor : SupColor);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, resistance ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
  }
//+------------------------------------------------------------------+
