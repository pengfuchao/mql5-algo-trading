//+------------------------------------------------------------------+
//|                                         PrecisionSniper.mq5     |
//|                           Developer: Hammad Dilber              |
//|                           Version  : 1.0                        |
//+------------------------------------------------------------------+
#property copyright "Hammad Dilber"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

// Plot 1 — EMA Fast
#property indicator_label1  "EMA Fast"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

// Plot 2 — EMA Slow
#property indicator_label2  "EMA Slow"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_width2  2

// Plot 3 — EMA Trend
#property indicator_label3  "EMA Trend"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDimGray
#property indicator_width3  1
#property indicator_style3  STYLE_DOT

// Plot 4 — Buy Arrow (below bar)
#property indicator_label4  "Long Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  3

// Plot 5 — Sell Arrow (above bar)
#property indicator_label5  "Short Signal"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  3

//+------------------------------------------------------------------+
//| ENUMS — dropdown menus in MT5 Inputs dialog                     |
//+------------------------------------------------------------------+
enum ENUM_PRESET
{
   PRESET_AUTO         = 0,  // Auto (timeframe-based)
   PRESET_SCALPING     = 1,  // Scalping
   PRESET_AGGRESSIVE   = 2,  // Aggressive
   PRESET_DEFAULT      = 3,  // Default
   PRESET_CONSERVATIVE = 4,  // Conservative
   PRESET_SWING        = 5,  // Swing
   PRESET_CRYPTO       = 6,  // Crypto
   PRESET_GOLD         = 7,  // Gold (Daily)
   PRESET_CUSTOM       = 8,  // Custom
};

enum ENUM_GRADE_FILTER
{
   GRADE_ALL      = 0,  // All Signals
   GRADE_A_PLUS_A = 1,  // A+ and A Only
   GRADE_A_PLUS   = 2,  // A+ Only
};

enum ENUM_BT_MODE
{
   BT_ALL_DATA    = 0,  // All Loaded Data
   BT_DATE_RANGE  = 1,  // Date Range (From / To)
   BT_ROLLING     = 2,  // Rolling Window (Last N Bars)
};

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input ENUM_PRESET       Preset        = PRESET_DEFAULT;  // Preset
input ENUM_TIMEFRAMES   HTF           = PERIOD_CURRENT;  // HTF Timeframe (PERIOD_CURRENT = off)
input int             C_EmaFast     = 9;    // [Custom] EMA Fast
input int             C_EmaSlow     = 21;   // [Custom] EMA Slow
input int             C_EmaTrend    = 55;   // [Custom] EMA Trend
input int             C_RSI         = 13;   // [Custom] RSI Length
input int             C_ATR         = 14;   // [Custom] ATR Length
input int             C_MinScore    = 5;    // [Custom] Min Score
input double          C_SLMult      = 1.5;  // [Custom] SL Multiplier
input double          TP1_RR        = 1.0;  // TP1 Risk:Reward
input double          TP2_RR        = 2.0;  // TP2 Risk:Reward
input double          TP3_RR        = 3.0;  // TP3 Risk:Reward
input double          SLMult        = 1.5;  // SL Multiplier (all presets)
input int             CooldownBars  = 5;    // Min Bars Between Signals
input bool            UseTrail      = true; // Enable Trailing Stop
input bool            StructureSL   = true; // Structure-Based SL
input int             SwingLB       = 10;   // Swing Lookback Bars
input ENUM_GRADE_FILTER GradeFilter   = GRADE_ALL;       // Grade Filter
input bool            HideCGrade    = true;   // Hide C-Grade Signals
input bool            ShowSignals   = true;   // Show Long/Short Signals
input bool            ShowEMA       = true;   // Show EMA Lines
input bool            ShowTPSL      = true;   // Show TP/SL Lines
input bool            ShowTrail     = true;   // Show Trail Stop Line
input bool            ShowDash      = true;   // Show Dashboard
// ── Backtest Filter ─────────────────────────────────────────────
input ENUM_BT_MODE    BtMode        = BT_ALL_DATA;          // Backtest Mode
input datetime        BtFrom        = D'2025.01.01 00:00';  // [Date Range] From
input datetime        BtTo          = D'2025.12.31 23:59';  // [Date Range] To
input int             BtRollingBars = 500;                  // [Rolling] Last N Bars

//+------------------------------------------------------------------+
//| BUFFERS                                                           |
//+------------------------------------------------------------------+
double bufEmaFast[];
double bufEmaSlow[];
double bufEmaTrend[];
double bufBuy[];
double bufSell[];

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
int    pFast, pSlow, pTrend, pRSI, pATR, pScore;
double pSLMult;

int hEmaFast, hEmaSlow, hEmaTrend, hRSI, hATR, hMACD, hADX, hHTFFast, hHTFSlow;

double g_entry   = 0;
double g_sl      = 0;
double g_tp1     = 0;
double g_tp2     = 0;
double g_tp3     = 0;
double g_trail   = 0;
double g_risk    = 0;
int    g_dir     = 0;
int    g_lastDir = 0;
int    g_eBar    = -1;
bool   g_tp1h    = false;
bool   g_tp2h    = false;
bool   g_tp3h    = false;
bool   g_slh     = false;

int      g_btTotal = 0;
int      g_btWins  = 0;
int      g_btLoss  = 0;
int      g_btBE    = 0;
double   g_btTotR  = 0;
double   g_btGW    = 0;
double   g_btGL    = 0;
// TP/SL breakdown counters
int      g_btTP1   = 0;   // trades that reached at least TP1
int      g_btTP2   = 0;   // trades that reached at least TP2
int      g_btTP3   = 0;   // trades that reached TP3
int      g_btSL    = 0;   // trades stopped out at full loss
datetime g_btEntryTime = 0;  // time of current open trade entry

string DPF = "PS_";

//+------------------------------------------------------------------+
void ApplyPreset()
{
   ENUM_PRESET p = Preset;
   if(p == PRESET_AUTO)
   {
      long sec = PeriodSeconds(PERIOD_CURRENT);
      if(sec <= 300)        p = PRESET_SCALPING;
      else if(sec <= 3600)  p = PRESET_DEFAULT;
      else if(sec <= 14400) p = PRESET_AGGRESSIVE;
      else                  p = PRESET_SWING;
   }
   if     (p==PRESET_SCALPING)     { pFast=5;  pSlow=13; pTrend=34;  pRSI=8;  pATR=10; pScore=4; pSLMult=0.8; }
   else if(p==PRESET_AGGRESSIVE)   { pFast=8;  pSlow=18; pTrend=50;  pRSI=11; pATR=12; pScore=3; pSLMult=1.2; }
   else if(p==PRESET_DEFAULT)      { pFast=9;  pSlow=21; pTrend=55;  pRSI=13; pATR=14; pScore=5; pSLMult=1.5; }
   else if(p==PRESET_CONSERVATIVE) { pFast=12; pSlow=26; pTrend=89;  pRSI=14; pATR=14; pScore=7; pSLMult=2.0; }
   else if(p==PRESET_SWING)        { pFast=13; pSlow=34; pTrend=89;  pRSI=21; pATR=20; pScore=6; pSLMult=2.5; }
   else if(p==PRESET_CRYPTO)       { pFast=9;  pSlow=21; pTrend=55;  pRSI=14; pATR=20; pScore=5; pSLMult=2.0; }
   else if(p==PRESET_GOLD)         { pFast=21; pSlow=55; pTrend=200; pRSI=21; pATR=20; pScore=7; pSLMult=2.5; }
   else                            { pFast=C_EmaFast; pSlow=C_EmaSlow; pTrend=C_EmaTrend; pRSI=C_RSI; pATR=C_ATR; pScore=C_MinScore; pSLMult=C_SLMult; }
   // Global SLMult input always overrides preset default
   pSLMult = SLMult;
}

string GetGrade(double s)
{
   if(s >= 8.0) return "A+";
   if(s >= 6.5) return "A";
   if(s >= 5.0) return "B";
   return "C";
}

bool FilterOK(double s)
{
   bool gOK = true;
   if     (GradeFilter == GRADE_A_PLUS)   gOK = (s >= 8.0);
   else if(GradeFilter == GRADE_A_PLUS_A) gOK = (s >= 6.5);
   return gOK && (HideCGrade ? s >= 5.0 : true);
}

// tradeTime = time[i] of the bar where trade was OPENED
// isForcedClose = true means trade closed by opposite signal (not actual SL hit)
void RecordTrade(double r, datetime tradeTime = 0, bool isForcedClose = false)
{
   // ── Backtest date/window filter ──────────────────────────────
   if(BtMode == BT_DATE_RANGE)
   {
      if(tradeTime < BtFrom || tradeTime > BtTo) return;
   }

   g_btTotal++;
   g_btTotR += r;
   if(r > 0)       { g_btWins++;  g_btGW += r; }
   else if(r < 0)  { g_btLoss++;  g_btGL += MathAbs(r); }
   else            { g_btBE++; }

   // ── TP/SL breakdown ──────────────────────────────────────────
   // Fix4: isForcedClose (opposite signal or end-of-history) should not be counted as actual SL
   if(g_tp3h)                    g_btTP3++;
   else if(g_tp2h)               g_btTP2++;
   else if(g_tp1h)               g_btTP1++;
   else if(r < 0 && !isForcedClose) g_btSL++;  // only count actual SL hits
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   ApplyPreset();

   SetIndexBuffer(0, bufEmaFast,  INDICATOR_DATA);
   SetIndexBuffer(1, bufEmaSlow,  INDICATOR_DATA);
   SetIndexBuffer(2, bufEmaTrend, INDICATOR_DATA);
   SetIndexBuffer(3, bufBuy,      INDICATOR_DATA);
   SetIndexBuffer(4, bufSell,     INDICATOR_DATA);

   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, -15);
   PlotIndexSetInteger(4, PLOT_ARROW_SHIFT,  15);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);

   hEmaFast  = iMA(_Symbol, PERIOD_CURRENT, pFast,  0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow  = iMA(_Symbol, PERIOD_CURRENT, pSlow,  0, MODE_EMA, PRICE_CLOSE);
   hEmaTrend = iMA(_Symbol, PERIOD_CURRENT, pTrend, 0, MODE_EMA, PRICE_CLOSE);
   hRSI      = iRSI(_Symbol, PERIOD_CURRENT, pRSI, PRICE_CLOSE);
   hATR      = iATR(_Symbol, PERIOD_CURRENT, pATR);
   hMACD     = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
   hADX      = iADX(_Symbol, PERIOD_CURRENT, 14);

   ENUM_TIMEFRAMES htf = (HTF == PERIOD_CURRENT) ? PERIOD_CURRENT : HTF;
   hHTFFast  = iMA(_Symbol, htf, pFast, 0, MODE_EMA, PRICE_CLOSE);
   hHTFSlow  = iMA(_Symbol, htf, pSlow, 0, MODE_EMA, PRICE_CLOSE);

   // Fix1: Validate HTF handles as well — silent failure causes wrong signals
   if(hEmaFast==INVALID_HANDLE || hEmaSlow==INVALID_HANDLE ||
      hEmaTrend==INVALID_HANDLE|| hRSI==INVALID_HANDLE ||
      hATR==INVALID_HANDLE     || hMACD==INVALID_HANDLE ||
      hADX==INVALID_HANDLE     || hHTFFast==INVALID_HANDLE ||
      hHTFSlow==INVALID_HANDLE)
   {
      Alert("PrecisionSniper: Failed to create indicator handles!");
      return INIT_FAILED;
   }

   string pNames[] = {"Auto","Scalping","Aggressive","Default","Conservative","Swing","Crypto","Gold","Custom"};
   IndicatorSetString(INDICATOR_SHORTNAME, "PrecSniper [" + pNames[(int)Preset] + "]");
   ClearDashboard();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hEmaFast);  IndicatorRelease(hEmaSlow);
   IndicatorRelease(hEmaTrend); IndicatorRelease(hRSI);
   IndicatorRelease(hATR);      IndicatorRelease(hMACD);
   IndicatorRelease(hADX);      IndicatorRelease(hHTFFast);
   IndicatorRelease(hHTFSlow);
   ClearDashboard();
   ObjectsDeleteAll(0, "PS_L_");
   ChartRedraw(0);
}

void ClearDashboard()
{
   int total = ObjectsTotal(0);
   for(int i = total-1; i >= 0; i--)
   {
      string nm = ObjectName(0,i);
      if(StringFind(nm, DPF) == 0)
         ObjectDelete(0, nm);
   }
}

//+------------------------------------------------------------------+
//| Draw TP/SL Lines                                                  |
//+------------------------------------------------------------------+
void DrawTPSLLines(datetime signalTime)
{
   if(!ShowTPSL) return;
   ObjectsDeleteAll(0, "PS_L_");

   datetime tEnd = TimeCurrent() + (datetime)(PeriodSeconds(PERIOD_CURRENT) * 5000);

   struct LevelDef { string name; double price; color clr; int wid; ENUM_LINE_STYLE sty; string lbl; };
   LevelDef lvl[5];
   lvl[0].name="PS_L_EN"; lvl[0].price=g_entry; lvl[0].clr=clrDodgerBlue; lvl[0].wid=2; lvl[0].sty=STYLE_SOLID; lvl[0].lbl="ENTRY "+DoubleToString(g_entry,_Digits);
   lvl[1].name="PS_L_SL"; lvl[1].price=g_sl;    lvl[1].clr=clrRed;        lvl[1].wid=2; lvl[1].sty=STYLE_SOLID; lvl[1].lbl="SL "   +DoubleToString(g_sl,_Digits);
   lvl[2].name="PS_L_T1"; lvl[2].price=g_tp1;   lvl[2].clr=clrLimeGreen;  lvl[2].wid=1; lvl[2].sty=STYLE_DASH;  lvl[2].lbl="TP1 "  +DoubleToString(g_tp1,_Digits);
   lvl[3].name="PS_L_T2"; lvl[3].price=g_tp2;   lvl[3].clr=clrLimeGreen;  lvl[3].wid=1; lvl[3].sty=STYLE_DASH;  lvl[3].lbl="TP2 "  +DoubleToString(g_tp2,_Digits);
   lvl[4].name="PS_L_T3"; lvl[4].price=g_tp3;   lvl[4].clr=clrLimeGreen;  lvl[4].wid=2; lvl[4].sty=STYLE_DASH;  lvl[4].lbl="TP3 "  +DoubleToString(g_tp3,_Digits);

   for(int i = 0; i < 5; i++)
   {
      ObjectCreate(0, lvl[i].name, OBJ_TREND, 0, signalTime, lvl[i].price, tEnd, lvl[i].price);
      ObjectSetInteger(0, lvl[i].name, OBJPROP_COLOR,      lvl[i].clr);
      ObjectSetInteger(0, lvl[i].name, OBJPROP_WIDTH,      lvl[i].wid);
      ObjectSetInteger(0, lvl[i].name, OBJPROP_STYLE,      lvl[i].sty);
      ObjectSetInteger(0, lvl[i].name, OBJPROP_RAY_RIGHT,  true);
      ObjectSetInteger(0, lvl[i].name, OBJPROP_RAY_LEFT,   false);
      ObjectSetInteger(0, lvl[i].name, OBJPROP_SELECTABLE, false);

      string lbName = lvl[i].name + "_lb";
      datetime tLbl = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT)*2;
      ObjectCreate(0, lbName, OBJ_TEXT, 0, tLbl, lvl[i].price);
      ObjectSetString(0,  lbName, OBJPROP_TEXT,     lvl[i].lbl);
      ObjectSetInteger(0, lbName, OBJPROP_COLOR,    lvl[i].clr);
      ObjectSetInteger(0, lbName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0,  lbName, OBJPROP_FONT,     "Arial Bold");
      ObjectSetInteger(0, lbName, OBJPROP_SELECTABLE, false);
   }

   if(UseTrail && ShowTrail)
   {
      ObjectCreate(0, "PS_L_TR", OBJ_TREND, 0, signalTime, g_trail, tEnd, g_trail);
      ObjectSetInteger(0, "PS_L_TR", OBJPROP_COLOR,      clrOrange);
      ObjectSetInteger(0, "PS_L_TR", OBJPROP_STYLE,      STYLE_DOT);
      ObjectSetInteger(0, "PS_L_TR", OBJPROP_RAY_RIGHT,  true);
      ObjectSetInteger(0, "PS_L_TR", OBJPROP_RAY_LEFT,   false);
      ObjectSetInteger(0, "PS_L_TR", OBJPROP_SELECTABLE, false);
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Dashboard helpers                                                |
//+------------------------------------------------------------------+
void MakeRect(string name, int x, int y, int w, int h, color bg, color border)
{
   if(ObjectFind(0,name) < 0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,      w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,      h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,    bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,      border);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,       false);
}

void MakeTxt(string name, int x, int y, string txt, color col, int sz, string font)
{
   if(ObjectFind(0,name) < 0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,     col);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,  sz);
   ObjectSetString (0,name,OBJPROP_FONT,      font);
   ObjectSetString (0,name,OBJPROP_TEXT,      txt);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,      false);
}

// Forward declarations
void Row(string id, int x, int y, int w, int h, int lw, string lbl, string val, color valC);
void MakeDRow(string id, int x, int y, int w, int h, string lbl1, string val1, color col1, string lbl2, string val2, color col2);

//+------------------------------------------------------------------+
//| UpdateDashboard                                                   |
//+------------------------------------------------------------------+
void UpdateDashboard(double bScore, double sScore, int htfBias,
                     string volReg, string trend, string status,
                     double rsi, double adx, bool strongTrend)
{
   if(!ShowDash) return;

   // Layout — top-right corner
   int X=10, Y=14, W=290, H=20, sep=2;

   double actScore = (g_dir==1)?bScore:(g_dir==-1)?sScore:MathMax(bScore,sScore);
   string wr   = g_btTotal>0 ? DoubleToString(g_btWins*100.0/g_btTotal,1)+"%" : "--";
   string avgR = g_btTotal>0 ? DoubleToString(g_btTotR/g_btTotal,2)+"R" : "--";
   double pf   = g_btGL>0 ? g_btGW/g_btGL : (g_btGW>0?999.0:0.0);
   string pfS  = (pf>=999)?"inf":DoubleToString(pf,2);
   string tpSt = g_tp3h?"TP3":g_tp2h?"TP2":g_tp1h?"TP1":"";

   color C_BG     = C'10,12,20';
   color C_PANEL  = C'20,24,40';
   color C_BORDER = C'70,80,120';
   color C_HEADER = C'28,34,58';
   color C_GREEN  = C'0,230,110';
   color C_RED    = C'255,70,70';
   color C_YELLOW = C'255,220,0';
   color C_GRAY   = C'160,170,200';
   color C_WHITE  = C'240,245,255';
   color C_BLUE   = C'80,160,255';
   color C_GOLD   = C'255,200,50';
   color C_ORANGE = C'255,165,0';

   // ── Title bar ──────────────────────────────────────
   string presetNames[] = {"Auto","Scalping","Aggressive","Default","Conservative","Swing","Crypto","Gold","Custom"};
   string presetStr = presetNames[(int)Preset];
   string gradeNames[] = {"All","A+ & A","A+ Only"};
   string gradeStr  = gradeNames[(int)GradeFilter];

   MakeRect(DPF+"T_BG", X, Y, W, 26, C'5,8,25', C_GOLD);
   MakeTxt (DPF+"T_TX", X+8,  Y+6, "PRECISION SNIPER", C_GOLD, 10, "Arial Bold");
   MakeTxt (DPF+"T_PR", X+185,Y+8, "["+presetStr+"]",   C_GRAY,  8, "Arial");
   Y += 29;

   // ── Trend row ──────────────────────────────────────
   color trendC = (trend=="Bullish")?C_GREEN:(trend=="Bearish")?C_RED:C_YELLOW;
   MakeRect(DPF+"TR_BG", X, Y, W, H, C_HEADER, trendC);
   MakeTxt (DPF+"TR_L",  X+8,   Y+4, "TREND",  C_GRAY,  7, "Arial");
   MakeTxt (DPF+"TR_V",  X+100, Y+4, trend,    trendC,  8, "Arial Bold");
   // Fix7: Long strings like PERIOD_H1 used to overflow the panel — use short form instead
   string tfStr = "";
   int per = Period();
   if(per==1)     tfStr="M1";
   else if(per==2)  tfStr="M2";
   else if(per==3)  tfStr="M3";
   else if(per==4)  tfStr="M4";
   else if(per==5)  tfStr="M5";
   else if(per==6)  tfStr="M6";
   else if(per==10) tfStr="M10";
   else if(per==12) tfStr="M12";
   else if(per==15) tfStr="M15";
   else if(per==20) tfStr="M20";
   else if(per==30) tfStr="M30";
   else if(per==16385) tfStr="H1";
   else if(per==16386) tfStr="H2";
   else if(per==16387) tfStr="H3";
   else if(per==16388) tfStr="H4";
   else if(per==16390) tfStr="H6";
   else if(per==16392) tfStr="H8";
   else if(per==16396) tfStr="H12";
   else if(per==16408) tfStr="D1";
   else if(per==32769) tfStr="W1";
   else if(per==49153) tfStr="MN";
   else               tfStr=IntegerToString(per);
   // Truncate symbol to max 6 chars to prevent panel overflow
   string symShort = StringSubstr(Symbol(), 0, 6);
   MakeTxt(DPF+"TR_TF", X+190, Y+4, tfStr+" | "+symShort, C_GRAY, 7, "Arial");
   Y += H+sep;

   // ── Score row ──────────────────────────────────────
   color scC = actScore>=7?C_GREEN:actScore>=5?C_YELLOW:C_RED;
   MakeRect(DPF+"SC_BG", X, Y, W, H, C_PANEL, scC);
   MakeTxt (DPF+"SC_L",  X+8,   Y+4, "SCORE",   C_GRAY, 7, "Arial");
   MakeTxt (DPF+"SC_V",  X+100, Y+4, DoubleToString(actScore,1)+"/10  ["+GetGrade(actScore)+"]", scC, 8, "Arial Bold");
   MakeTxt (DPF+"SC_BS", X+195, Y+4, "B:"+DoubleToString(bScore,1)+" S:"+DoubleToString(sScore,1), C_GRAY, 7, "Arial");
   Y += H+sep;

   // ── Signal bar ──────────────────────────────────────
   color sigBg = g_dir==1?C'0,80,40':g_dir==-1?C'90,20,20':C'20,22,40';
   color sigBd = g_dir==1?C_GREEN:g_dir==-1?C_RED:C_BORDER;
   string sigTx = g_dir==1?"▲  LONG ACTIVE":g_dir==-1?"▼  SHORT ACTIVE":"—  WAITING FOR SIGNAL";
   MakeRect(DPF+"SG_BG", X, Y, W, H+4, sigBg, sigBd);
   MakeTxt (DPF+"SG_TX", X+8, Y+5, sigTx, sigBd, 9, "Arial Bold");
   if(tpSt!="")
      MakeTxt(DPF+"SG_TP", X+200, Y+7, tpSt+" Hit", C_GREEN, 7, "Arial Bold");
   else
      MakeTxt(DPF+"SG_TP", X+200, Y+7, "", C_GRAY, 7, "Arial");
   Y += H+8;

   // ── Separator ──────────────────────────────────────
   MakeRect(DPF+"SP1", X, Y, W, 1, C_BORDER, C_BORDER);
   Y += 3;

   // ── Column headers ──────────────────────────────────
   int LW=105, VW=W-LW-4;
   MakeRect(DPF+"CH_BG", X, Y, W, H-2, C_HEADER, C_BORDER);
   MakeTxt (DPF+"CH_L",  X+8,      Y+3, "INDICATOR",    C_YELLOW, 7, "Arial Bold");
   MakeTxt (DPF+"CH_V",  X+LW+8,   Y+3, "VALUE",        C_YELLOW, 7, "Arial Bold");
   Y += H;

   // ── Data rows ──────────────────────────────────────
   string htfStr = htfBias==1?"▲ Bullish":htfBias==-1?"▼ Bearish":"● Neutral";
   color  htfC   = htfBias==1?C_GREEN:htfBias==-1?C_RED:C_YELLOW;
   color  rsiC   = rsi>70?C_RED:rsi<30?C_GREEN:rsi>50?C_GREEN:C_RED;
   color  adxC   = strongTrend?C_GREEN:C_ORANGE;
   color  volC   = volReg=="High"?C_RED:volReg=="Low"?C_GRAY:C_GREEN;

   Row(DPF+"D0", X,Y,W,H,LW, "HTF Bias",   htfStr, htfC); Y+=H+sep;
   Row(DPF+"D1", X,Y,W,H,LW, "RSI",        DoubleToString(rsi,1)+(rsi>70?" OB":rsi<30?" OS":""), rsiC); Y+=H+sep;
   Row(DPF+"D2", X,Y,W,H,LW, "ADX",        DoubleToString(adx,1)+(strongTrend?" Strong":" Weak"), adxC); Y+=H+sep;
   Row(DPF+"D3", X,Y,W,H,LW, "Volatility", volReg, volC); Y+=H+sep;
   Row(DPF+"D4", X,Y,W,H,LW, "Grade Filter", gradeStr, C_WHITE); Y+=H+sep;

   // ── Separator ──────────────────────────────────────
   MakeRect(DPF+"SP2", X, Y, W, 1, C_BORDER, C_BORDER);
   Y += 3;

   // ── Backtest header ────────────────────────────────
   // Backtest mode label
   string btModeStr = "";
   if(BtMode == BT_DATE_RANGE)
      btModeStr = TimeToString(BtFrom, TIME_DATE)+" → "+TimeToString(BtTo, TIME_DATE);
   else if(BtMode == BT_ROLLING)
      btModeStr = "Last "+IntegerToString(BtRollingBars)+" Bars";
   else
      btModeStr = "All Data";
   string btHeader = "BACKTEST  ["+btModeStr+"]";

   MakeRect(DPF+"BT_BG", X, Y, W, H-2, C_HEADER, C_BLUE);
   MakeTxt (DPF+"BT_TX", X+8, Y+3, btHeader, C_YELLOW, 7, "Arial Bold");
   Y += H;

   string tradesS = IntegerToString(g_btTotal)+"  ("+IntegerToString(g_btWins)+"W / "+IntegerToString(g_btLoss)+"L / "+IntegerToString(g_btBE)+"BE)";
   color  wrC     = g_btTotal>0?(g_btWins*100.0/g_btTotal>=55?C_GREEN:g_btWins*100.0/g_btTotal>=45?C_YELLOW:C_RED):C_GRAY;
   color  totRC   = g_btTotR>0?C_GREEN:g_btTotR<0?C_RED:C_GRAY;
   color  pfC     = pf>=1.5?C_GREEN:pf>=1.0?C_YELLOW:C_RED;

   // TP/SL breakdown strings
   string tp1S = IntegerToString(g_btTP1)+" hit";
   string tp2S = IntegerToString(g_btTP2)+" hit";
   string tp3S = IntegerToString(g_btTP3)+" hit";
   string slS  = IntegerToString(g_btSL)+" full SL  |  "+IntegerToString(g_btBE)+" BE";
   color  tp1C = g_btTP1>0?C_GREEN:C_GRAY;
   color  tp2C = g_btTP2>0?C_GREEN:C_GRAY;
   color  tp3C = g_btTP3>0?C_GREEN:C_GRAY;
   color  slC  = g_btSL>0?C_RED:C_GRAY;

   Row(DPF+"B0", X,Y,W,H,LW, "Trades",         tradesS,  C_WHITE);    Y+=H+sep;
   Row(DPF+"B1", X,Y,W,H,LW, "Win Rate",        wr,       wrC);       Y+=H+sep;
   Row(DPF+"B2", X,Y,W,H,LW, "Profit Factor",   pfS,      pfC);       Y+=H+sep;
   Row(DPF+"B3", X,Y,W,H,LW, "Avg R",           avgR,     C_WHITE);   Y+=H+sep;
   Row(DPF+"B4", X,Y,W,H,LW, "Total R",         DoubleToString(g_btTotR,2)+"R", totRC); Y+=H+sep;
   // ── TP/SL breakdown ──────────────────────────────
   Row(DPF+"B5", X,Y,W,H,LW, "TP1 Reached",     tp1S,     tp1C);      Y+=H+sep;
   Row(DPF+"B6", X,Y,W,H,LW, "TP2 Reached",     tp2S,     tp2C);      Y+=H+sep;
   Row(DPF+"B7", X,Y,W,H,LW, "TP3 Reached",     tp3S,     tp3C);      Y+=H+sep;
   Row(DPF+"B8", X,Y,W,H,LW, "SL / BE",         slS,      slC);

   ChartRedraw(0);
}

// Single full-width row: label on left, value on right
void Row(string id, int x, int y, int w, int h, int lw,
         string lbl, string val, color valC)
{
   color C_PANEL  = C'20,24,40';
   color C_BORDER = C'70,80,120';
   color C_GRAY   = C'160,170,200';
   MakeRect(id+"_BG", x, y, w, h, C_PANEL, C_BORDER);
   MakeTxt (id+"_L",  x+8,    y+4, lbl, C_GRAY, 7, "Arial");
   MakeTxt (id+"_V",  x+lw+8, y+4, val, valC,   8, "Arial Bold");
}

void MakeDRow(string id, int x, int y, int w, int h,
              string lbl1, string val1, color col1,
              string lbl2, string val2, color col2)
{
   // kept for compatibility — not used in new dashboard
   Row(id+"a", x, y, w/2-1, h, w/4, lbl1, val1, col1);
   Row(id+"b", x+w/2+1, y, w/2-1, h, w/4, lbl2, val2, col2);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   if(rates_total < pTrend + 60) return 0;

   //--- Step 1: Copy all indicator data as SERIES (index 0 = newest bar)
   double ef[], es[], et[], rsi[], atr[], mm[], ms[], adx[], dip[], dim[], htfF[], htfS[];
   ArraySetAsSeries(ef,   true); ArraySetAsSeries(es,   true);
   ArraySetAsSeries(et,   true); ArraySetAsSeries(rsi,  true);
   ArraySetAsSeries(atr,  true); ArraySetAsSeries(mm,   true);
   ArraySetAsSeries(ms,   true); ArraySetAsSeries(adx,  true);
   ArraySetAsSeries(dip,  true); ArraySetAsSeries(dim,  true);
   ArraySetAsSeries(htfF, true); ArraySetAsSeries(htfS, true);

   int copyCount = (prev_calculated <= 1) ? rates_total : 3;

   if(CopyBuffer(hEmaFast,  0, 0, copyCount, ef)  <= 0) return 0;
   if(CopyBuffer(hEmaSlow,  0, 0, copyCount, es)  <= 0) return 0;
   if(CopyBuffer(hEmaTrend, 0, 0, copyCount, et)  <= 0) return 0;
   if(CopyBuffer(hRSI,      0, 0, copyCount, rsi) <= 0) return 0;
   if(CopyBuffer(hATR,      0, 0, copyCount, atr) <= 0) return 0;
   if(CopyBuffer(hMACD,     0, 0, copyCount, mm)  <= 0) return 0;
   if(CopyBuffer(hMACD,     1, 0, copyCount, ms)  <= 0) return 0;
   if(CopyBuffer(hADX,      0, 0, copyCount, adx) <= 0) return 0;
   if(CopyBuffer(hADX,      1, 0, copyCount, dip) <= 0) return 0;
   if(CopyBuffer(hADX,      2, 0, copyCount, dim) <= 0) return 0;

   int htfBars = iBars(_Symbol, HTF);
   int htfCopyCount = (HTF == PERIOD_CURRENT) ? copyCount : htfBars;
   if(CopyBuffer(hHTFFast, 0, 0, htfCopyCount, htfF) <= 0) return 0;
   if(CopyBuffer(hHTFSlow, 0, 0, htfCopyCount, htfS) <= 0) return 0;

   //--- Step 2: Set output buffers as NON-SERIES (index 0 = oldest bar)
   //    This matches OnCalculate's close[]/high[] direction
   ArraySetAsSeries(bufEmaFast,  false);
   ArraySetAsSeries(bufEmaSlow,  false);
   ArraySetAsSeries(bufEmaTrend, false);
   ArraySetAsSeries(bufBuy,      false);
   ArraySetAsSeries(bufSell,     false);

   //--- Step 3: Reset state on full recalc (guards against double counting on minor ticks)
   bool fullReset = (prev_calculated == 0) || (rates_total - prev_calculated > 1);
   if(fullReset)
   {
      g_entry=0; g_sl=0; g_tp1=0; g_tp2=0; g_tp3=0; g_trail=0; g_risk=0;
      g_dir=0; g_lastDir=0; g_eBar=-1;
      g_tp1h=false; g_tp2h=false; g_tp3h=false; g_slh=false;
      g_btTotal=0; g_btWins=0; g_btLoss=0; g_btBE=0; g_btTotR=0; g_btGW=0; g_btGL=0; g_btTP1=0; g_btTP2=0; g_btTP3=0; g_btSL=0;
      ArrayInitialize(bufBuy,   0.0);
      ArrayInitialize(bufSell,  0.0);
   }

   //--- Step 4: Fill EMA buffers for all bars
   //    i = forward index (0=oldest), r = series index (0=newest)
   //    Start from 1 (not 0) to stay consistent with signal scan minimum start
   int s = (prev_calculated <= 1) ? 1 : prev_calculated - 1;
   for(int i = s; i < rates_total; i++)
   {
      int r = rates_total - 1 - i;
      bufEmaFast[i]  = ShowEMA ? ((r < ArraySize(ef)) ? ef[r]  : EMPTY_VALUE) : EMPTY_VALUE;
      bufEmaSlow[i]  = ShowEMA ? ((r < ArraySize(es)) ? es[r]  : EMPTY_VALUE) : EMPTY_VALUE;
      bufEmaTrend[i] = ShowEMA ? ((r < ArraySize(et)) ? et[r]  : EMPTY_VALUE) : EMPTY_VALUE;
      bufBuy[i]  = 0.0;
      bufSell[i] = 0.0;
   }

   //--- Step 5: Signal scan (skip last bar)
   int sf = (prev_calculated <= 2) ? 1 : prev_calculated - 1;
   if(fullReset) sf = 1;

   // Rolling window: only count trades from last BtRollingBars bars
   // Fix3: In BT_ROLLING mode, ALWAYS reset stats and scan from rolling window start
   // Otherwise incremental recalc retains old (out-of-window) trade counts
   int rollingStart = 0;
   if(BtMode == BT_ROLLING)
   {
      rollingStart = MathMax(1, rates_total - 1 - BtRollingBars);
      // Reset stats + trade state on EVERY call (full + incremental)
      g_btTotal=0; g_btWins=0; g_btLoss=0; g_btBE=0; g_btTotR=0; g_btGW=0; g_btGL=0; g_btTP1=0; g_btTP2=0; g_btTP3=0; g_btSL=0;
      g_entry=0; g_sl=0; g_tp1=0; g_tp2=0; g_tp3=0; g_trail=0; g_risk=0;
      g_dir=0; g_lastDir=0; g_eBar=-1;
      g_tp1h=false; g_tp2h=false; g_tp3h=false; g_slh=false;
      sf = rollingStart;
   }

   for(int i = sf; i < rates_total - 1; i++)
   {
      // Rolling mode: skip bars outside window (also resets open trade state at boundary)
      if(BtMode == BT_ROLLING && i < rollingStart) continue;
      int r  = rates_total - 1 - i;  // series index for this bar
      int r1 = r + 1;                // series index for previous bar
      if(r1 >= ArraySize(ef) || r1 >= ArraySize(es)) continue;

      double cEf  = ef[r],  cEs  = es[r],  cEt  = et[r];
      double pEf  = ef[r1], pEs  = es[r1];
      double cRsi = rsi[r], cAtr = atr[r];
      double cMm  = mm[r],  cMs  = ms[r];
      double cAdx = adx[r], cDip = dip[r], cDim = dim[r];
      // Fix6b: Safely align multi-timeframe index using iBarShift to eliminate look-ahead bias
      int htfShift = (HTF == PERIOD_CURRENT) ? r : iBarShift(_Symbol, HTF, time[i], false);
      int htfR = htfShift;
      if(htfR < 0 || htfR >= ArraySize(htfF)) htfR = 0;
      double cHtfF = htfF[htfR], cHtfS = htfS[htfR];
      double cl   = close[i], hi = high[i], lo = low[i];

      // Volume
      double volSum = 0;
      int volCnt = MathMin(20, i+1);
      for(int k = 0; k < volCnt; k++) volSum += (double)tick_volume[i-k];
      bool volAbove = (tick_volume[i] > (volCnt>0 ? volSum/volCnt : 1.0) * 1.2);

      double typPrice = (hi + lo + cl) / 3.0; // Correct Typical Price calculation
      bool   strong = (cAdx > 20.0);
      int    htfBias= (cHtfF > cHtfS) ? 1 : (cHtfF < cHtfS) ? -1 : 0;

      // ATR volatility regime
      double atrSum = 0;
      int atrCnt = MathMin(42, i+1);
      for(int k = 0; k < atrCnt; k++) { int rk=rates_total-1-(i-k); if(rk>=0&&rk<ArraySize(atr)) atrSum+=atr[rk]; }
      double atrSma = (atrCnt>0) ? atrSum/atrCnt : cAtr;
      double vr     = (atrSma>0) ? cAtr/atrSma : 1.0;
      string volReg = (vr>1.3)?"High":(vr<0.7)?"Low":"Normal";

      // ── Scoring ──────────────────────────────────────────────────────
      // Previous bar RSI for momentum check
      double pRsiVal = (r+1 < ArraySize(rsi)) ? rsi[r+1] : cRsi;

      // EMA spacing — stronger trend = wider gap
      double emaGap   = MathAbs(cEf - cEs);
      bool   emaSep   = (emaGap > cAtr * 0.15);  // EMAs must be meaningfully separated

      // RSI momentum: rising for buy, falling for sell
      bool   rsiMomUp = (cRsi > pRsiVal);
      bool   rsiMomDn = (cRsi < pRsiVal);

      // Price must be clearly above/below trend EMA (not just touching)
      bool   aboveTrend = (cl > cEt + cAtr * 0.1);
      bool   belowTrend = (cl < cEt - cAtr * 0.1);

      // MACD histogram direction (momentum confirmation)
      double pMm = (r+1 < ArraySize(mm)) ? mm[r+1] : cMm;
      double pMs = (r+1 < ArraySize(ms)) ? ms[r+1] : cMs;
      bool   macdHistUp = ((cMm - cMs) > (pMm - pMs));  // histogram expanding bullish
      bool   macdHistDn = ((cMm - cMs) < (pMm - pMs));  // histogram expanding bearish

      // Fix2: When HTF = PERIOD_CURRENT (off), HTF score stays zero — avoids inflating from current TF
      bool htfEnabled = (HTF != PERIOD_CURRENT);

      double bScore = 0;
      bScore += (cEf > cEs && emaSep)                 ? 1.5 : 0.0;  // EMA aligned + separated
      bScore += aboveTrend                             ? 1.5 : 0.0;  // clearly above trend
      bScore += (cRsi > 50 && cRsi < 70 && rsiMomUp)  ? 1.5 : 0.0;  // RSI bullish + rising
      bScore += macdHistUp                             ? 1.0 : 0.0;  // MACD momentum up
      bScore += (cl > typPrice)                        ? 0.5 : 0.0;  // above Typical Price
      bScore += volAbove                               ? 0.5 : 0.0;  // volume confirmation
      bScore += (strong && cDip > cDim)                ? 1.0 : 0.0;  // ADX + DI+
      bScore += (htfEnabled && htfBias == 1)           ? 2.0 : 0.0;  // HTF alignment — only if HTF active

      double sScore = 0;
      sScore += (cEf < cEs && emaSep)                  ? 1.5 : 0.0;
      sScore += belowTrend                              ? 1.5 : 0.0;
      sScore += (cRsi < 50 && cRsi > 30 && rsiMomDn)   ? 1.5 : 0.0;
      sScore += macdHistDn                              ? 1.0 : 0.0;
      sScore += (cl < typPrice)                         ? 0.5 : 0.0;  // below Typical Price
      sScore += volAbove                                ? 0.5 : 0.0;
      sScore += (strong && cDim > cDip)                 ? 1.0 : 0.0;
      sScore += (htfEnabled && htfBias == -1)           ? 2.0 : 0.0;  // HTF alignment — only if HTF active

      // ── EMA crossover ────────────────────────────────────────────────
      bool bullCross = (pEf <= pEs) && (cEf > cEs);
      bool bearCross = (pEf >= pEs) && (cEf < cEs);

      // ── Extra hard filters (must pass regardless of score) ───────────
      // 1. Price must NOT be extended too far from EMA Fast (avoid chasing)
      bool notExtended = (MathAbs(cl - cEf) < cAtr * 1.5);
      // 2. HTF must NOT be against us (neutral is OK, opposite is not)
      bool htfNotAgainst = (htfBias != -1);  // for buy
      bool htfNotAgainstS= (htfBias != 1);   // for sell
      // 3. Candle body check — signal bar should have a real body (not a doji)
      double body = MathAbs(close[i] - open[i]);
      bool   realBody = (body > cAtr * 0.1);

      bool cooldownOK = (g_eBar < 0) || ((i - g_eBar) >= CooldownBars);
      bool doBuy  = bullCross && aboveTrend && (cRsi<72) && realBody && notExtended && htfNotAgainst
                    && (bScore>=(double)pScore) && FilterOK(bScore) && (g_lastDir!=1) && cooldownOK;
      bool doSell = bearCross && belowTrend && (cRsi>28) && realBody && notExtended && htfNotAgainstS
                    && (sScore>=(double)pScore) && FilterOK(sScore) && (g_lastDir!=-1) && cooldownOK;
      if(doBuy && doSell) doSell = false;

      // Open trade
      if(doBuy)
      {
         if(g_dir==-1 && !g_slh && g_eBar>=0)
         {
            // Bug2 fix: respect trailing stop when force-closing on new signal
            double rv;
            if(UseTrail) rv = g_tp3h?TP2_RR:g_tp2h?TP1_RR:g_tp1h?0.0:-1.0;
            else         rv = g_tp3h?TP3_RR:g_tp2h?TP2_RR:g_tp1h?TP1_RR:-1.0;
            RecordTrade(rv, g_btEntryTime, true);  // Fix4: force-close — not an actual SL hit
         }
         g_entry=cl; g_dir=1; g_lastDir=1; g_btEntryTime=time[i];
         if(StructureSL)
         {
            double swL=lo;
            for(int k=1;k<=SwingLB&&(i-k)>=0;k++) swL=MathMin(swL,low[i-k]);
            g_sl=swL-cAtr*0.2;
            if(cl-g_sl < cAtr*0.5) g_sl=cl-cAtr*0.5;
         }
         else g_sl=cl-cAtr*pSLMult;
         g_risk=MathAbs(cl-g_sl);
         g_tp1=cl+g_risk*TP1_RR; g_tp2=cl+g_risk*TP2_RR; g_tp3=cl+g_risk*TP3_RR;
         g_trail=g_sl; g_tp1h=false; g_tp2h=false; g_tp3h=false; g_slh=false; g_eBar=i;
         if(i==rates_total-2) DrawTPSLLines(time[i]);
      }
      else if(doSell)
      {
         if(g_dir==1 && !g_slh && g_eBar>=0)
         {
            // Bug2 fix: respect trailing stop when force-closing on new signal
            double rv;
            if(UseTrail) rv = g_tp3h?TP2_RR:g_tp2h?TP1_RR:g_tp1h?0.0:-1.0;
            else         rv = g_tp3h?TP3_RR:g_tp2h?TP2_RR:g_tp1h?TP1_RR:-1.0;
            RecordTrade(rv, g_btEntryTime, true);  // Fix4: force-close — not an actual SL hit
         }
         g_entry=cl; g_dir=-1; g_lastDir=-1; g_btEntryTime=time[i];
         if(StructureSL)
         {
            double swH=hi;
            for(int k=1;k<=SwingLB&&(i-k)>=0;k++) swH=MathMax(swH,high[i-k]);
            g_sl=swH+cAtr*0.2;
            if(g_sl-cl < cAtr*0.5) g_sl=cl+cAtr*0.5;
         }
         else g_sl=cl+cAtr*pSLMult;
         g_risk=MathAbs(cl-g_sl);
         g_tp1=cl-g_risk*TP1_RR; g_tp2=cl-g_risk*TP2_RR; g_tp3=cl-g_risk*TP3_RR;
         g_trail=g_sl; g_tp1h=false; g_tp2h=false; g_tp3h=false; g_slh=false; g_eBar=i;
         if(i==rates_total-2) DrawTPSLLines(time[i]);
      }

      // TP/SL Management
      // Pessimistic same-bar exit: If SL/Trail is hit, ignore any TPs hit on the SAME bar.
      if(g_eBar>=0 && i>g_eBar && g_dir!=0 && !g_slh)
      {
         if(g_dir==1)
         {
            double pt = g_trail;  // snapshot trail before any TP updates
            bool wasTp1 = g_tp1h;
            bool wasTp2 = g_tp2h;
            bool wasTp3 = g_tp3h;

            bool slHit = (lo <= pt);
            bool tp1HitThisBar = (hi >= g_tp1 && !wasTp1);
            bool tp2HitThisBar = (hi >= g_tp2 && !wasTp2);
            bool tp3HitThisBar = (hi >= g_tp3 && !wasTp3);

            if(slHit)
            {
               g_slh=true; g_lastDir=0;
               RecordTrade(UseTrail ? (wasTp3 ? TP2_RR : wasTp2 ? TP1_RR : wasTp1 ? 0.0 : -1.0)
                                    : (wasTp3 ? TP3_RR : wasTp2 ? TP2_RR : wasTp1 ? TP1_RR : -1.0), g_btEntryTime);
            }
            else
            {
               if(tp1HitThisBar) { g_tp1h=true; if(UseTrail) g_trail=g_entry; }
               if(tp2HitThisBar) { g_tp2h=true; if(UseTrail) g_trail=g_tp1;   }
               if(tp3HitThisBar) { g_tp3h=true; if(UseTrail) g_trail=g_tp2;   }
            }
         }
         else
         {
            double pt = g_trail;
            bool wasTp1 = g_tp1h;
            bool wasTp2 = g_tp2h;
            bool wasTp3 = g_tp3h;

            bool slHit = (hi >= pt);
            bool tp1HitThisBar = (lo <= g_tp1 && !wasTp1);
            bool tp2HitThisBar = (lo <= g_tp2 && !wasTp2);
            bool tp3HitThisBar = (lo <= g_tp3 && !wasTp3);

            if(slHit)
            {
               g_slh=true; g_lastDir=0;
               RecordTrade(UseTrail ? (wasTp3 ? TP2_RR : wasTp2 ? TP1_RR : wasTp1 ? 0.0 : -1.0)
                                    : (wasTp3 ? TP3_RR : wasTp2 ? TP2_RR : wasTp1 ? TP1_RR : -1.0), g_btEntryTime);
            }
            else
            {
               if(tp1HitThisBar) { g_tp1h=true; if(UseTrail) g_trail=g_entry; }
               if(tp2HitThisBar) { g_tp2h=true; if(UseTrail) g_trail=g_tp1;   }
               if(tp3HitThisBar) { g_tp3h=true; if(UseTrail) g_trail=g_tp2;   }
            }
         }
      }

      // Fill signal buffers
      if(ShowSignals && doBuy)  bufBuy[i]  = lo - cAtr*0.8;
      if(ShowSignals && doSell) bufSell[i] = hi + cAtr*0.8;

   }

   //--- Step 5b: End-of-history open trade recording (Bug3 fix)
   // If a trade was opened but never closed by SL/TP by end of history,
   // record its current state so Total = Wins + Losses + BE always.
   // Use a flag to avoid double-counting on incremental recalcs.
   if(fullReset && g_dir != 0 && !g_slh && g_eBar >= 0)
   {
      double rv;
      if(UseTrail) rv = g_tp3h?TP2_RR:g_tp2h?TP1_RR:g_tp1h?0.0:-1.0;
      else         rv = g_tp3h?TP3_RR:g_tp2h?TP2_RR:g_tp1h?TP1_RR:-1.0;
      RecordTrade(rv, g_btEntryTime, true);  // Fix4: end-of-history — not an actual SL hit
   }

   //--- Step 6: Current (last) bar processing
   int last = rates_total - 1;
   {
      if(g_eBar>=0 && g_dir!=0 && !g_slh)
      {
         double lastHi=high[last], lastLo=low[last];
         if(g_dir==1)
         {
            double pt=g_trail;  // snapshot before TP updates
            bool wasTp1 = g_tp1h;
            bool wasTp2 = g_tp2h;
            bool wasTp3 = g_tp3h;

            bool slHit = (lastLo <= pt);
            bool tp1HitThisBar = (lastHi >= g_tp1 && !wasTp1);
            bool tp2HitThisBar = (lastHi >= g_tp2 && !wasTp2);
            bool tp3HitThisBar = (lastHi >= g_tp3 && !wasTp3);

            if(slHit)
            {
               g_slh=true; g_lastDir=0;
               RecordTrade(UseTrail ? (wasTp3 ? TP2_RR : wasTp2 ? TP1_RR : wasTp1 ? 0.0 : -1.0)
                                    : (wasTp3 ? TP3_RR : wasTp2 ? TP2_RR : wasTp1 ? TP1_RR : -1.0), g_btEntryTime);
            }
            else
            {
               if(tp1HitThisBar) { g_tp1h=true; if(UseTrail) g_trail=g_entry; }
               if(tp2HitThisBar) { g_tp2h=true; if(UseTrail) g_trail=g_tp1;   }
               if(tp3HitThisBar) { g_tp3h=true; if(UseTrail) g_trail=g_tp2;   }
            }
         }
         else
         {
            double pt=g_trail;
            bool wasTp1 = g_tp1h;
            bool wasTp2 = g_tp2h;
            bool wasTp3 = g_tp3h;

            bool slHit = (lastHi >= pt);
            bool tp1HitThisBar = (lastLo <= g_tp1 && !wasTp1);
            bool tp2HitThisBar = (lastLo <= g_tp2 && !wasTp2);
            bool tp3HitThisBar = (lastLo <= g_tp3 && !wasTp3);

            if(slHit)
            {
               g_slh=true; g_lastDir=0;
               RecordTrade(UseTrail ? (wasTp3 ? TP2_RR : wasTp2 ? TP1_RR : wasTp1 ? 0.0 : -1.0)
                                    : (wasTp3 ? TP3_RR : wasTp2 ? TP2_RR : wasTp1 ? TP1_RR : -1.0), g_btEntryTime);
            }
            else
            {
               if(tp1HitThisBar) { g_tp1h=true; if(UseTrail) g_trail=g_entry; }
               if(tp2HitThisBar) { g_tp2h=true; if(UseTrail) g_trail=g_tp1;   }
               if(tp3HitThisBar) { g_tp3h=true; if(UseTrail) g_trail=g_tp2;   }
            }
         }
         // Update trail line
         if(ShowTPSL && UseTrail && ShowTrail && ObjectFind(0,"PS_L_TR")>=0)
         {
            ObjectSetDouble(0,"PS_L_TR",OBJPROP_PRICE,0,g_trail);
            ObjectSetDouble(0,"PS_L_TR",OBJPROP_PRICE,1,g_trail);
         }
      }

      // Dashboard on last bar
      if(0 < ArraySize(ef))
      {
         double cAtr2= (0<ArraySize(atr))?atr[0]:0;
         double typPrice2=(high[last]+low[last]+close[last])/3.0; // Correct Typical Price calculation
         int htfBias2=(htfF[0]>htfS[0])?1:(htfF[0]<htfS[0])?-1:0;
         bool strong2=(adx[0]>20.0);

         double atrSum2=0; int atrCnt2=MathMin(42,last+1);
         for(int k=0;k<atrCnt2;k++){int rk=k;if(rk<ArraySize(atr))atrSum2+=atr[rk];}
         double atrSma2=(atrCnt2>0)?atrSum2/atrCnt2:cAtr2;
         double vr2=(atrSma2>0)?cAtr2/atrSma2:1.0;
         string volReg2=(vr2>1.3)?"High":(vr2<0.7)?"Low":"Normal";

         double cEf2=ef[0],cEs2=es[0],cEt2=et[0];
         double cl2=close[last];
         double pRsi2=(1<ArraySize(rsi))?rsi[1]:rsi[0];
         double pMm2 =(1<ArraySize(mm)) ?mm[1] :mm[0];
         double pMs2 =(1<ArraySize(ms)) ?ms[1] :ms[0];
         double emaGap2   = MathAbs(cEf2-cEs2);
         bool   emaSep2   = (emaGap2 > cAtr2*0.15);
         bool   rsiMomUp2 = (rsi[0]>pRsi2);
         bool   rsiMomDn2 = (rsi[0]<pRsi2);
         bool   aboveTrend2=(cl2>cEt2+cAtr2*0.1);
         bool   belowTrend2=(cl2<cEt2-cAtr2*0.1);
         bool   macdHistUp2=((mm[0]-ms[0])>(pMm2-pMs2));
         bool   macdHistDn2=((mm[0]-ms[0])<(pMm2-pMs2));

         string trend2=(cEf2>cEs2&&aboveTrend2)?"Bullish":(cEf2<cEs2&&belowTrend2)?"Bearish":"Neutral";
         string status2="No Trade";
         if(g_dir!=0&&!g_slh)
            status2=g_tp3h?"TP3 Hit":g_tp2h?"TP2 Hit":g_tp1h?"TP1 Hit":"Active";

         // Full score for dashboard — matches new scoring logic
         double volSum2=0; int volCnt2=MathMin(20,last+1);
         for(int k=0;k<volCnt2;k++) volSum2+=(double)tick_volume[last-k];
         bool volAbove2=(tick_volume[last]>(volCnt2>0?volSum2/volCnt2:1.0)*1.2);
         double bScFull=0,sScFull=0;
         // Fix2b: Dashboard score also checks HTF enabled — same logic as signal scan
         bool htfEnabled2 = (HTF != PERIOD_CURRENT);
         bScFull+=(cEf2>cEs2&&emaSep2)?1.5:0; bScFull+=aboveTrend2?1.5:0;
         bScFull+=(rsi[0]>50&&rsi[0]<70&&rsiMomUp2)?1.5:0; bScFull+=macdHistUp2?1.0:0;
         bScFull+=(cl2>typPrice2)?0.5:0; bScFull+=volAbove2?0.5:0;
         bScFull+=(strong2&&dip[0]>dim[0])?1.0:0; bScFull+=(htfEnabled2&&htfBias2==1)?2.0:0;
         sScFull+=(cEf2<cEs2&&emaSep2)?1.5:0; sScFull+=belowTrend2?1.5:0;
         sScFull+=(rsi[0]<50&&rsi[0]>30&&rsiMomDn2)?1.5:0; sScFull+=macdHistDn2?1.0:0;
         sScFull+=(cl2<typPrice2)?0.5:0; sScFull+=volAbove2?0.5:0;
         sScFull+=(strong2&&dim[0]>dip[0])?1.0:0; sScFull+=(htfEnabled2&&htfBias2==-1)?2.0:0;

         UpdateDashboard(bScFull, sScFull, htfBias2, volReg2, trend2, status2, rsi[0], adx[0], strong2);
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+