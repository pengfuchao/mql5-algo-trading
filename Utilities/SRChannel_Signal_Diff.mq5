//+------------------------------------------------------------------+
//|                                    SRChannel_Signal_Diff.mq5     |
//|                                                                  |
//|  診斷 EA：比對兩個世代的 Support_Resistance_Channels 突破訊號。    |
//|  **不下任何單**，只讀 buffer 並記錄分歧。                          |
//|                                                                  |
//|  背景：2026-07-21 發現同一組名目參數 (CWP=2/MaxSR=3) 下，          |
//|  S7 世代 (26e0f6a) 與 HEAD 世代的回測交易數相差 20 倍             |
//|  (103 vs 2088)，但兩份指標原始碼的 diff 在該參數下逐行等價。       |
//|                                                                  |
//|  為何是 EA 而非 script：指標只寫入 buffer[0] 與 buffer[1]          |
//|  (`bufResBrk[1] = resBroken ? cClosed : 0.0`)，**不回填歷史**。    |
//|  因此必須在 Strategy Tester 中逐根推進取樣，即時圖表上讀到的       |
//|  歷史一律為 0。                                                   |
//|                                                                  |
//|  前置作業 (兩支指標都要在 MQL5\Indicators\ 下且已編譯)：           |
//|    1. HEAD 版：Support_Resistance_Channels.ex5                    |
//|       —— 無參數 iCustom + global variable override               |
//|    2. S7 版 ：Support_Resistance_Channels_S7ref.ex5               |
//|       —— 由 26e0f6a 的原始碼另存此檔名後編譯，positional 傳參      |
//|                                                                  |
//|  用法：Strategy Tester 選本 EA，設定與回測 baseline 相同           |
//|  (EURUSD H1, 2020.06.01-2026.06.01)，跑完看 Journal 摘要。        |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"
#property tester_indicator "Support_Resistance_Channels.ex5"
#property tester_indicator "Support_Resistance_Channels_S7ref.ex5"
//--- 附中間值列印的診斷副本 (僅存在於終端機，不進 repo)
#property tester_indicator "SRC_dbg_head.ex5"
#property tester_indicator "SRC_dbg_s7.ex5"

//--- 必須與指標的 enum 數值一致
enum ENUM_SR_SOURCE
  {
   SRC_HIGHLOW = 0,   // High/Low
   SRC_CLOSEOPEN = 1  // Close/Open
  };

enum ENUM_SR_WIDTH_MODE
  {
   WIDTH_RANGE_PCT = 0, // Range %
   WIDTH_ATR       = 1  // ATR
  };

input group "指標名稱"
input string InpHeadName = "Support_Resistance_Channels";       // HEAD 版
input string InpRefName  = "Support_Resistance_Channels_S7ref"; // S7 版

input group "指標參數 (兩邊使用完全相同的值)"
input int             InpPivotPeriod    = 10;
input ENUM_SR_SOURCE  InpSourceMode     = SRC_HIGHLOW;
input int             InpChannelWidthPct= 2;
input int             InpMinStrength    = 1;
input int             InpMaxNumSR       = 3;
input int             InpLoopback       = 290;
input ENUM_SR_WIDTH_MODE InpChannelWidthMode = WIDTH_RANGE_PCT;
input int             InpATRLen         = 14;
input double          InpATRMult        = 0.3;
input bool            InpUseVolumeFilter= false;
input int             InpVolMaLen       = 20;
input double          InpVolMult        = 1.0;
input double          InpRetestTolerATR = 0.10;
input int             InpRetestExpiryBars = 20;

input group "Override 身分 (須與 EA 一致才能命中同一組 global variable)"
input ulong           InpMagic          = 770010;

input group "輸出"
input bool            InpLogEveryDiff   = true;   // 逐筆列印分歧 (量大時可關)
input int             InpMaxDiffLogged  = 50;     // 最多列印幾筆分歧

//--- breakout buffer index (兩個世代相同)
#define BUF_RES_BRK 2
#define BUF_SUP_BRK 3

int      hHead    = INVALID_HANDLE;   // HEAD 指標，override 傳參
int      hHeadPos = INVALID_HANDLE;   // HEAD 指標，positional 傳參 (對照用)
int      hRef     = INVALID_HANDLE;   // S7 指標，positional 傳參
datetime lastBar = 0;

//--- 統計
long g_bars = 0;
long g_headSignals = 0;
long g_headPosSignals = 0;
long g_refSignals  = 0;
long g_diverged    = 0;
int  g_diffLogged  = 0;
datetime g_firstDiv = 0;

//+------------------------------------------------------------------+
//| 寫入 HEAD 版指標所需的 global variable override                   |
//|   複製自 Strategy_SR_Channel_Breakout.mq5，須與其保持一致          |
//+------------------------------------------------------------------+
void WriteSRIndicatorOverrides()
  {
   string base   = "MT5SL_SRCH_" + _Symbol + "_" + IntegerToString((int)_Period) + "_";
   string prefix = base + IntegerToString((long)InpMagic) + "_";

   GlobalVariableSet(base + "ACTIVE", (double)InpMagic);
   GlobalVariableSet(prefix + "STAMP",    (double)TimeLocal());
   GlobalVariableSet(prefix + "PIVOT",    InpPivotPeriod);
   GlobalVariableSet(prefix + "SOURCE",   (int)InpSourceMode);
   GlobalVariableSet(prefix + "CWP",      InpChannelWidthPct);
   GlobalVariableSet(prefix + "MINSTR",   InpMinStrength);
   GlobalVariableSet(prefix + "MAXSR",    InpMaxNumSR);
   GlobalVariableSet(prefix + "LOOPBACK", InpLoopback);
   GlobalVariableSet(prefix + "WIDTHMODE",(int)InpChannelWidthMode);
   GlobalVariableSet(prefix + "ATRLEN",   InpATRLen);
   GlobalVariableSet(prefix + "ATRMULT",  InpATRMult);
   GlobalVariableSet(prefix + "USEVOL",   0.0);   // 與 EA 相同：指標端量過濾一律關閉
   GlobalVariableSet(prefix + "VOLMALEN", InpVolMaLen);
   GlobalVariableSet(prefix + "VOLMULT",  InpVolMult);
   GlobalVariableSet(prefix + "RTOL",     InpRetestTolerATR);
   GlobalVariableSet(prefix + "REXP",     InpRetestExpiryBars);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   //--- HEAD 版：先寫 override，再以無參數 iCustom 建立 (與 EA 完全相同的路徑)
   WriteSRIndicatorOverrides();
   hHead = iCustom(_Symbol, _Period, InpHeadName);
   if(hHead == INVALID_HANDLE)
     {
      PrintFormat("無法載入 HEAD 版指標 '%s'，error=%d", InpHeadName, GetLastError());
      return(INIT_FAILED);
     }

   //--- HEAD 版但改用 positional 傳參：分離「指標邏輯」與「參數傳遞」兩個變因
   //    若此組與 S7 版一致 → 指標邏輯無恙，問題出在 override 傳參
   //    若此組與 HEAD(override) 一致 → 問題在指標邏輯本身
   hHeadPos = iCustom(_Symbol, _Period, InpHeadName,
                      InpPivotPeriod, InpSourceMode, InpChannelWidthPct,
                      InpMinStrength, InpMaxNumSR, InpLoopback,
                      InpChannelWidthMode, InpATRLen, InpATRMult,
                      InpUseVolumeFilter, InpVolMaLen, InpVolMult,
                      InpRetestTolerATR, InpRetestExpiryBars);
   if(hHeadPos == INVALID_HANDLE)
     {
      PrintFormat("無法以 positional 方式載入 HEAD 版指標，error=%d", GetLastError());
      return(INIT_FAILED);
     }

   //--- S7 版：positional 傳參 (與 26e0f6a 的 EA 完全相同的路徑)
   hRef = iCustom(_Symbol, _Period, InpRefName,
                  InpPivotPeriod, InpSourceMode, InpChannelWidthPct,
                  InpMinStrength, InpMaxNumSR, InpLoopback,
                  InpChannelWidthMode, InpATRLen, InpATRMult,
                  InpUseVolumeFilter, InpVolMaLen, InpVolMult,
                  InpRetestTolerATR, InpRetestExpiryBars);
   if(hRef == INVALID_HANDLE)
     {
      PrintFormat("無法載入 S7 版指標 '%s'，error=%d (是否已另存並編譯？)", InpRefName, GetLastError());
      return(INIT_FAILED);
     }

   PrintFormat("SignalDiff 啟動：HEAD='%s' REF='%s' CWP=%d MaxSR=%d",
               InpHeadName, InpRefName, InpChannelWidthPct, InpMaxNumSR);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   PrintFormat("=== SR Channel 訊號比對結果 (%s %s) ===",
               _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period));
   PrintFormat("取樣 K 棒數     : %I64d", g_bars);
   if(g_bars > 0)
     {
      PrintFormat("HEAD override   : %I64d (%.2f%%)", g_headSignals,    100.0*g_headSignals/g_bars);
      PrintFormat("HEAD positional : %I64d (%.2f%%)", g_headPosSignals, 100.0*g_headPosSignals/g_bars);
      PrintFormat("S7   positional : %I64d (%.2f%%)", g_refSignals,     100.0*g_refSignals/g_bars);
      if(g_headPosSignals == g_refSignals)
         Print("→ HEADpos == S7：指標邏輯無恙，問題在 override 傳參路徑。");
      else if(g_headPosSignals == g_headSignals)
         Print("→ HEADpos == HEADovr：問題在指標邏輯本身，與傳參方式無關。");
      else
         Print("→ 三組互不相同：傳參與邏輯可能都有影響，需個別再查。");
     }
   PrintFormat("HEADovr vs S7 分歧根數 : %I64d", g_diverged);
   if(g_firstDiv > 0)
      PrintFormat("第一根分歧      : %s", TimeToString(g_firstDiv, TIME_DATE|TIME_MINUTES));
   else if(g_bars > 0)
      Print("兩者完全一致 —— 分歧不在指標訊號，應往 EA 端查。");

   if(hHead    != INVALID_HANDLE) IndicatorRelease(hHead);
   if(hHeadPos != INVALID_HANDLE) IndicatorRelease(hHeadPos);
   if(hRef  != INVALID_HANDLE) IndicatorRelease(hRef);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   //--- 僅在新 K 棒取樣，且與 EA 一致地讀 shift=1 的已收盤棒
   datetime curBar[1];
   if(CopyTime(_Symbol, _Period, 0, 1, curBar) < 1) return;
   if(curBar[0] == lastBar) return;

   if(BarsCalculated(hHead) < 2 || BarsCalculated(hHeadPos) < 2 || BarsCalculated(hRef) < 2) return;

   double hRes[1], hSup[1], pRes[1], pSup[1], rRes[1], rSup[1];
   if(CopyBuffer(hHead,    BUF_RES_BRK, 1, 1, hRes) < 1) return;
   if(CopyBuffer(hHead,    BUF_SUP_BRK, 1, 1, hSup) < 1) return;
   if(CopyBuffer(hHeadPos, BUF_RES_BRK, 1, 1, pRes) < 1) return;
   if(CopyBuffer(hHeadPos, BUF_SUP_BRK, 1, 1, pSup) < 1) return;
   if(CopyBuffer(hRef,     BUF_RES_BRK, 1, 1, rRes) < 1) return;
   if(CopyBuffer(hRef,     BUF_SUP_BRK, 1, 1, rSup) < 1) return;

   lastBar = curBar[0];
   g_bars++;

   bool headSig    = (hRes[0] > 0.0) || (hSup[0] > 0.0);
   bool headPosSig = (pRes[0] > 0.0) || (pSup[0] > 0.0);
   bool refSig     = (rRes[0] > 0.0) || (rSup[0] > 0.0);
   if(headSig)    g_headSignals++;
   if(headPosSig) g_headPosSignals++;
   if(refSig)     g_refSignals++;

   if(headSig != refSig)
     {
      g_diverged++;
      if(g_firstDiv == 0) g_firstDiv = curBar[0];

      if(InpLogEveryDiff && g_diffLogged < InpMaxDiffLogged)
        {
         g_diffLogged++;
         PrintFormat("DIFF @ %s  HEADovr(res=%.5f sup=%.5f)  HEADpos(res=%.5f sup=%.5f)  S7(res=%.5f sup=%.5f)",
                     TimeToString(curBar[0], TIME_DATE|TIME_MINUTES),
                     hRes[0], hSup[0], pRes[0], pSup[0], rRes[0], rSup[0]);
        }
     }
  }
//+------------------------------------------------------------------+
