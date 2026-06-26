//+------------------------------------------------------------------+
//|                                           PrecisionSniperEA.mq5 |
//|                           Developer: Hammad Dilber & Antigravity |
//|                           Version  : 1.20                        |
//|                           Description: PrecisionSniper EA        |
//+------------------------------------------------------------------+
#property copyright "Hammad Dilber & Antigravity"
#property version   "1.20"
#property description "PrecisionSniper 實盤自動跟單 Expert Advisor"

// 引入 MT5 標準交易庫
#include <Trade\Trade.mqh>

//====================================================================
// ⚠️【列舉定義 (Enums)】
//====================================================================
enum ENUM_PRESET
{
   PRESET_AUTO         = 0,  // Auto (時間框架自適應)
   PRESET_SCALPING     = 1,  // Scalping (超短線)
   PRESET_AGGRESSIVE   = 2,  // Aggressive (積極)
   PRESET_DEFAULT      = 3,  // Default (預設)
   PRESET_CONSERVATIVE = 4,  // Conservative (保守)
   PRESET_SWING        = 5,  // Swing (波段)
   PRESET_CRYPTO       = 6,  // Crypto (加密貨幣)
   PRESET_GOLD         = 7,  // Gold (黃金日線)
   PRESET_CUSTOM       = 8,  // Custom (自定義)
};

enum ENUM_GRADE_FILTER
{
   GRADE_ALL      = 0,  // 所有信號 (All Signals)
   GRADE_A_PLUS_A = 1,  // 僅限 A+ 與 A 級
   GRADE_A_PLUS   = 2,  // 僅限 A+ 級
};

enum ENUM_SL_TYPE
{
   SL_STRUCTURE  = 0,  // 結構止損 (Swing High/Low)
   SL_FIXED_ATR  = 1,  // 固定 ATR 止損
};

//====================================================================
// ── 輸入參數區 (Inputs) ──
//====================================================================
input string          __EA_SET__     = "====== [ EA 交易帳戶管理 ] ======";
input double          InpLots        = 0.1;           // 預設開倉手數 (Fixed Lots)
input bool            InpUseRiskSize = false;         // 啟用動態風險倉位控制
input double          InpRiskPercent = 1.0;           // 每筆交易風險比例 (帳戶餘額 %)
input int             InpMagicNumber = 909090;        // EA 專屬特徵碼 (Magic Number)
input string          InpComment     = "PrecSniperEA"; // 訂單注釋
input int             InpMaxSpread   = 30;            // 最大容許價差 (Points)
input bool            InpPartialExit = true;          // 啟用分批止盈出場 (1/3 模式)
input bool            InpTradeOnFirstBar = false;     // 掛載後第一根新K是否允許交易

input string          __IND_SET__    = "====== [ PrecisionSniper 核心參數 ] ======";
input string          InpIndName     = "PrecisionSniper"; // 指標名稱 (對應的 EX5 檔名)
input ENUM_PRESET     Preset         = PRESET_DEFAULT;    // 策略預設模板 (Preset)
input ENUM_TIMEFRAMES HTF            = PERIOD_CURRENT;    // HTF 大週期過濾 (PERIOD_CURRENT = 關閉)
input int             C_EmaFast      = 9;                 // [Custom] EMA 快線週期
input int             C_EmaSlow      = 21;                // [Custom] EMA 慢線週期
input int             C_EmaTrend     = 55;                // [Custom] EMA 趨勢過濾週期
input int             C_RSI          = 13;                // [Custom] RSI 週期
input int             C_ATR          = 14;                // [Custom] ATR 週期
input int             C_MinScore     = 5;                 // [Custom] 最低入場評分 (1~10)
input double          C_SLMult       = 1.5;               // [Custom] ATR 止損倍數

input string          __RISK_SET__   = "====== [ 策略風險與出場管理 ] ======";
input double          TP1_RR         = 1.0;          // TP1 風險回報比 (Risk:Reward)
input double          TP2_RR         = 2.0;          // TP2 風險回報比 (Risk:Reward)
input double          TP3_RR         = 3.0;          // TP3 風險回報比 (Risk:Reward)
input double          SLMult         = 1.5;          // 全域止損倍數 (覆蓋 Preset)
input int             CooldownBars   = 5;            // 信號最小冷卻棒數 (Bars)
input bool            UseTrail       = true;         // 啟用移動止損保本
input ENUM_SL_TYPE    SLType         = SL_STRUCTURE; // 止損計算方式
input int             SwingLB        = 10;           // 結構止損回溯棒數

input string          __FILTER_SET__ = "====== [ 信號過濾篩選 ] ======";
input ENUM_GRADE_FILTER GradeFilter  = GRADE_ALL;      // 信號等級篩選 (Grade Filter)
input bool            HideCGrade     = true;         // 隱藏並拒絕 C-Grade 信號

//====================================================================
// 全域變數宣告
//====================================================================
int      hIndicator     = INVALID_HANDLE; // Custom Indicator 句柄
int      hATR           = INVALID_HANDLE; // ATR 句柄 (EA 計算 SL 用)
datetime lastBarTime    = 0;              // 記錄最新 K 線開盤時間
CTrade   trade;                           //--- 全域變數宣告區
double   g_point;                         // 當前商品的點值 (SYMBOL_POINT)
int      g_digits;                        // 當前商品的小數點位數

// 用於記錄當前持倉狀態 (Restorable State)
double   g_entryPrice   = 0;
double   g_slPrice      = 0;
double   g_tp1Price     = 0;
double   g_tp2Price     = 0;
double   g_tp3Price     = 0;
double   g_riskVal      = 0;
int      g_positionDir  = 0; // 0=None, 1=Long, -1=Short
bool     g_tp1Hit       = false; // 已觸及 TP1 (分批階段旗標，與 SL/UseTrail 解耦)
bool     g_tp2Hit       = false; // 已觸及 TP2
bool     g_showVisual   = true;  // 是否繪製視覺物件 (優化模式自動關閉以加速)

//====================================================================
// 輔助函數宣告
//====================================================================
ENUM_PRESET EffectivePreset()
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
   return p;
}

int EffectiveATRPeriod()
{
   ENUM_PRESET p = EffectivePreset();
   if     (p == PRESET_SCALPING)     return 10;
   else if(p == PRESET_AGGRESSIVE)   return 12;
   else if(p == PRESET_DEFAULT)      return 14;
   else if(p == PRESET_CONSERVATIVE) return 14;
   else if(p == PRESET_SWING)        return 20;
   else if(p == PRESET_CRYPTO)       return 20;
   else if(p == PRESET_GOLD)         return 20;
   return C_ATR;
}

int VolumeDigitsFromStep(double step)
{
   int digits = 0;
   while(step > 0.0 && step < 1.0 && digits < 8)
   {
      step *= 10.0;
      digits++;
   }
   return digits;
}

double NormalizeVolumeDown(double volume)
{
   double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   if(step <= 0.0) return 0.0;
   double normalized = MathFloor(volume / step) * step;
   return NormalizeDouble(normalized, VolumeDigitsFromStep(step));
}

bool TradeRetcodeOK(string action)
{
   uint rc = trade.ResultRetcode();
   if(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED)
      return true;

   Print("PrecisionSniperEA: ", action, " 失敗。retcode=", rc, " desc=", trade.ResultRetcodeDescription());
   return false;
}

bool ModifyPositionChecked(ulong ticket, double sl, double tp, string action)
{
   if(!trade.PositionModify(ticket, sl, tp))
   {
      Print("PrecisionSniperEA: ", action, " 呼叫失敗。desc=", trade.ResultRetcodeDescription());
      return false;
   }
   return TradeRetcodeOK(action);
}

bool ClosePositionChecked(ulong ticket, string action)
{
   if(!trade.PositionClose(ticket))
   {
      Print("PrecisionSniperEA: ", action, " 呼叫失敗。desc=", trade.ResultRetcodeDescription());
      return false;
   }
   return TradeRetcodeOK(action);
}

bool ClosePartialChecked(ulong ticket, double volume, string action)
{
   if(volume <= 0.0) return true;
   if(!trade.PositionClosePartial(ticket, volume))
   {
      Print("PrecisionSniperEA: ", action, " 呼叫失敗。volume=", volume, " desc=", trade.ResultRetcodeDescription());
      return false;
   }
   return TradeRetcodeOK(action);
}

bool TradingAllowedFor(ENUM_POSITION_TYPE type)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      Print("PrecisionSniperEA: Terminal/account 不允許 EA 交易，略過進場。");
      return false;
   }

   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
   {
      Print("PrecisionSniperEA: Symbol trade mode 不允許新倉，mode=", (int)mode);
      return false;
   }
   if(type == POSITION_TYPE_BUY && mode == SYMBOL_TRADE_MODE_SHORTONLY)
   {
      Print("PrecisionSniperEA: Symbol 僅允許 short，略過 Buy。");
      return false;
   }
   if(type == POSITION_TYPE_SELL && mode == SYMBOL_TRADE_MODE_LONGONLY)
   {
      Print("PrecisionSniperEA: Symbol 僅允許 long，略過 Sell。");
      return false;
   }
   return true;
}

//====================================================================
// EA 初始化函數 (OnInit)
//====================================================================
int OnInit()
{
   g_point  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   if(g_point <= 0.0)
   {
      Print("PrecisionSniperEA: SYMBOL_POINT 無效。");
      return INIT_FAILED;
   }
   if(InpMagicNumber <= 0)
   {
      Print("PrecisionSniperEA: InpMagicNumber 必須大於 0，避免管理人工單。");
      return INIT_PARAMETERS_INCORRECT;
   }
   if((!InpUseRiskSize && InpLots <= 0.0) || (InpUseRiskSize && InpRiskPercent <= 0.0))
   {
      Print("PrecisionSniperEA: 固定手數或風險比例設定無效。");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(C_EmaFast < 1 || C_EmaSlow < 1 || C_EmaTrend < 1 || C_RSI < 1 || C_ATR < 1 ||
      C_MinScore < 0 || SLMult <= 0.0 || TP1_RR <= 0.0 || TP2_RR <= 0.0 || TP3_RR <= 0.0 ||
      TP1_RR > TP2_RR || TP2_RR > TP3_RR || CooldownBars < 0 || SwingLB < 1)
   {
      Print("PrecisionSniperEA: PrecisionSniper inputs 無效。");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // 設定交易 Magic Number
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpMaxSpread);
   
   // 優化模式 (Optimization) 時關閉所有視覺物件以大幅加速。
   // ⚠️ ShowSignals 必須恆為 true：指標僅在 ShowSignals 時填入 Buffer 3/4 箭頭，
   //    關閉將導致 EA 永遠讀不到信號。其餘 4 個視覺旗標 (EMA/TPSL/Trail/Dash) 才可關。
   g_showVisual = !(bool)MQLInfoInteger(MQL_OPTIMIZATION);

   // 初始化 Custom Indicator 句柄
   // 傳入與指標完全一致的參數列表以確保即時同步
   hIndicator = iCustom(Symbol(), PERIOD_CURRENT, InpIndName,
                        Preset, HTF, C_EmaFast, C_EmaSlow, C_EmaTrend, C_RSI, C_ATR, C_MinScore, C_SLMult,
                        TP1_RR, TP2_RR, TP3_RR, SLMult, CooldownBars, UseTrail, (SLType == SL_STRUCTURE), SwingLB,
                        GradeFilter, HideCGrade,
                        true, g_showVisual, g_showVisual, g_showVisual, g_showVisual, // 信號(恆開)、均線、TPSL、移動止損線、儀表板
                        0, D'2025.01.01 00:00', D'2025.12.31 23:59', 500 // 預設回測參數 (無實盤影響)
                       );
   
   if(hIndicator == INVALID_HANDLE)
   {
      Alert("PrecisionSniperEA: 無法載入指標 [" + InpIndName + "]！請檢查檔名是否正確。");
      return INIT_FAILED;
   }
   
   // 初始化 ATR 句柄 (用於 EA 自主 SL 計算)
   int pATR = EffectiveATRPeriod();
              
   hATR = iATR(Symbol(), PERIOD_CURRENT, pATR);
   if(hATR == INVALID_HANDLE)
   {
      Print("PrecisionSniperEA: 無法載入 ATR 指標！");
      return INIT_FAILED;
   }
   
   Print("PrecisionSniperEA: 初始化成功！", (g_showVisual ? "" : " (優化模式：視覺物件已關閉)"));

   // 繪製初始 Dashboard 背景與標題 (優化模式略過)
   if(g_showVisual) CreateEAPanel();

   return INIT_SUCCEEDED;
}

//====================================================================
// EA 卸載函數 (OnDeinit)
//====================================================================
void OnDeinit(const int reason)
{
   if(hIndicator != INVALID_HANDLE) IndicatorRelease(hIndicator);
   if(hATR != INVALID_HANDLE)       IndicatorRelease(hATR);
   
   // 清除 EA 自繪面板物件
   ObjectsDeleteAll(0, "PSEA_");
   ChartRedraw(0);
   
   Print("PrecisionSniperEA: 結束運行。");
}

//====================================================================
// EA 主循環函數 (OnTick)
//====================================================================
void OnTick()
{
   // 1. 每一跳 (Every Tick) 優先進行：移動止損與分批止盈管理
   ManagePositionExits();
   
   // 更新 EA Dashboard 面板數據 (優化模式略過繪圖)
   if(g_showVisual) UpdateEAPanel();

   // 2. 新 Bar 檢測：信號掃描僅在新 K 線開盤時觸發 (防止重複下單且大幅節省 CPU)
   datetime currentBarTime = (datetime)SeriesInfoInteger(Symbol(), PERIOD_CURRENT, SERIES_LASTBAR_DATE);
   if(currentBarTime == lastBarTime) return;

   // 預設掛載後先等待下一根新 K，避免吃到 EA 啟動前已存在的 stale signal。
   if(lastBarTime == 0 && !InpTradeOnFirstBar)
   {
      lastBarTime = currentBarTime;
      Print("PrecisionSniperEA: 初次掛載，略過第一根已完成訊號；下一根新 K 開始交易。");
      return;
   }
   
   // 3. spread 過濾器，防止極端點差下單
   int currentSpread = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   if(currentSpread > InpMaxSpread)
   {
      Print("PrecisionSniperEA: 當前點差 (", currentSpread, ") 大於設定最大值 (", InpMaxSpread, ")，暫停開倉掃描。");
      return;
   }
   
   // 4. 讀取指標緩衝區數據 (Buffer 3 = Buy Arrow, Buffer 4 = Sell Arrow)
   //    讀取 bar 1 (上根剛收盤的 K 線)，確保信號 100% 凍結、不Repaint！
   double buySig[1];
   double sellSig[1];

   if(BarsCalculated(hIndicator) < 2 || BarsCalculated(hATR) < 2)
   {
      Print("PrecisionSniperEA: 指標/ATR 尚未完成計算，等待同一根 K 的後續 tick 重試。");
      return;
   }
   
   if(CopyBuffer(hIndicator, 3, 1, 1, buySig) <= 0 || CopyBuffer(hIndicator, 4, 1, 1, sellSig) <= 0)
   {
      Print("PrecisionSniperEA: 無法讀取指標信號緩衝區！");
      return;
   }
   
   bool signalBuy  = (buySig[0] > 0);
   bool signalSell = (sellSig[0] > 0);

   // Buffer 成功讀取後才標記此 K 已處理；spread/buffer 暫時失敗不會永久漏訊號。
   lastBarTime = currentBarTime;
   
   // 5. 交易決策執行
   if(signalBuy)
   {
      Print("PrecisionSniperEA: 偵測到 Buy 入場信號！");
      // 信號反向平倉：先平掉所有賣單
      if(!ClosePositions(POSITION_TYPE_SELL))
      {
         Print("PrecisionSniperEA: 反向 Sell 平倉未完全成功，取消本根 Buy 進場。");
         return;
      }
      // 執行買入開倉
      OpenPosition(POSITION_TYPE_BUY);
   }
   else if(signalSell)
   {
      Print("PrecisionSniperEA: 偵測到 Sell 入場信號！");
      // 信號反向平倉：先平掉所有買單
      if(!ClosePositions(POSITION_TYPE_BUY))
      {
         Print("PrecisionSniperEA: 反向 Buy 平倉未完全成功，取消本根 Sell 進場。");
         return;
      }
      // 執行賣出開倉
      OpenPosition(POSITION_TYPE_SELL);
   }
}

//====================================================================
// 開倉執行函數 (OpenPosition)
//====================================================================
void OpenPosition(ENUM_POSITION_TYPE type)
{
   // 檢查是否有同類型持倉以防重覆開倉
   if(HasPosition(type)) return;
   if(!TradingAllowedFor(type)) return;
   
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
   {
      Print("PrecisionSniperEA: Bid/Ask 無效，放棄下單。");
      return;
   }
   double entryPrice = (type == POSITION_TYPE_BUY) ? ask : bid;
   
   // 1. 讀取 ATR
   double atrBuf[1];
   if(CopyBuffer(hATR, 0, 1, 1, atrBuf) <= 0)
   {
      Print("PrecisionSniperEA: ATR 讀取失敗，無法下單！");
      return;
   }
   double atrVal = atrBuf[0];
   if(atrVal <= 0) return;
   
   // 2. 計算止損價格 (SL Price)
   double slPrice = 0;
   double pSLMult = (SLMult > 0) ? SLMult : C_SLMult;
   
   if(SLType == SL_STRUCTURE)
   {
      // 結構止損計算：尋找歷史 Swing High/Low
      if(type == POSITION_TYPE_BUY)
      {
         double minL = iLow(Symbol(), PERIOD_CURRENT, 1);
         for(int k = 2; k <= SwingLB + 1; k++)
         {
            minL = MathMin(minL, iLow(Symbol(), PERIOD_CURRENT, k));
         }
         slPrice = minL - atrVal * 0.2;
         // 限制最小止損寬度 (0.5 * ATR)
         if(entryPrice - slPrice < atrVal * 0.5)
         {
            slPrice = entryPrice - atrVal * 0.5;
         }
      }
      else
      {
         double maxH = iHigh(Symbol(), PERIOD_CURRENT, 1);
         for(int k = 2; k <= SwingLB + 1; k++)
         {
            maxH = MathMax(maxH, iHigh(Symbol(), PERIOD_CURRENT, k));
         }
         slPrice = maxH + atrVal * 0.2;
         // 限制最小止損寬度 (0.5 * ATR)
         if(slPrice - entryPrice < atrVal * 0.5)
         {
            slPrice = entryPrice + atrVal * 0.5;
         }
      }
   }
   else // 固定 ATR 止損
   {
      slPrice = (type == POSITION_TYPE_BUY) ? (entryPrice - atrVal * pSLMult) : (entryPrice + atrVal * pSLMult);
   }
   
   slPrice = NormalizeDouble(slPrice, g_digits);

   // ── Broker 最小停損距離 (STOPS_LEVEL) 強制驗證 ──
   // SL 距離不足會被伺服器拒單；不足時將 SL 外推至最小合法距離並記錄。
   long   stopsLevelPts = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   long   freezeLevelPts = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_FREEZE_LEVEL);
   long   spreadPts = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   long   minStopPts = ((stopsLevelPts > freezeLevelPts) ? stopsLevelPts : freezeLevelPts) + spreadPts;
   double minStopDist = (double)minStopPts * g_point;
   if(minStopDist > 0)
   {
      if(type == POSITION_TYPE_BUY && (entryPrice - slPrice) < minStopDist)
      {
         slPrice = NormalizeDouble(entryPrice - minStopDist, g_digits);
         Print("PrecisionSniperEA: SL 距離小於 StopsLevel，已外推至 ", slPrice);
      }
      else if(type == POSITION_TYPE_SELL && (slPrice - entryPrice) < minStopDist)
      {
         slPrice = NormalizeDouble(entryPrice + minStopDist, g_digits);
         Print("PrecisionSniperEA: SL 距離小於 StopsLevel，已外推至 ", slPrice);
      }
   }

   double riskVal = MathAbs(entryPrice - slPrice);
   if(riskVal <= 0)
   {
      Print("PrecisionSniperEA: 風險距離為零，放棄下單以策安全。");
      return;
   }
   
   // 3. 計算開倉手數 (Lots)
   double lots = InpLots;
   double riskUSD = 0.0;
   double lossPerLot = 0.0;
   ENUM_ORDER_TYPE orderType = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(InpUseRiskSize)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      riskUSD = equity * InpRiskPercent / 100.0;
      double profitAtSL = 0.0;
      if(equity <= 0.0 || riskUSD <= 0.0 ||
         !OrderCalcProfit(orderType, Symbol(), 1.0, entryPrice, slPrice, profitAtSL))
      {
         Print("PrecisionSniperEA: risk sizing 所需資料無效，放棄下單。");
         return;
      }
      lossPerLot = MathAbs(profitAtSL);
      if(lossPerLot <= 0.0)
      {
         Print("PrecisionSniperEA: 1 lot 到 SL 的虧損估算無效，放棄下單。");
         return;
      }
      lots = riskUSD / lossPerLot;
   }
   
   // 限制手數上下限
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0 || maxLot <= 0.0 || stepLot <= 0.0)
   {
      Print("PrecisionSniperEA: broker volume constraints 無效，放棄下單。");
      return;
   }
   double normalizedLots = NormalizeVolumeDown(MathMin(maxLot, lots));
   if(normalizedLots < minLot)
   {
      if(InpUseRiskSize && lossPerLot > 0.0 && (lossPerLot * minLot) > riskUSD)
      {
         Print("PrecisionSniperEA: 最小手數實際風險超過設定風險，放棄下單。");
         return;
      }
      normalizedLots = minLot;
   }
   lots = normalizedLots;
   
   // 4. 計算三個止盈價格 (Take Profits)
   double tp3Price = (type == POSITION_TYPE_BUY) ? (entryPrice + riskVal * TP3_RR) : (entryPrice - riskVal * TP3_RR);
   tp3Price = NormalizeDouble(tp3Price, g_digits);

   // TP3 為伺服器端止盈，同樣需滿足 StopsLevel
   if(minStopDist > 0)
   {
      if(type == POSITION_TYPE_BUY && (tp3Price - entryPrice) < minStopDist)
         tp3Price = NormalizeDouble(entryPrice + minStopDist, g_digits);
      else if(type == POSITION_TYPE_SELL && (entryPrice - tp3Price) < minStopDist)
         tp3Price = NormalizeDouble(entryPrice - minStopDist, g_digits);
   }
   
   double plannedTp1 = (type == POSITION_TYPE_BUY) ? (entryPrice + riskVal * TP1_RR) : (entryPrice - riskVal * TP1_RR);
   double plannedTp2 = (type == POSITION_TYPE_BUY) ? (entryPrice + riskVal * TP2_RR) : (entryPrice - riskVal * TP2_RR);
   plannedTp1 = NormalizeDouble(plannedTp1, g_digits);
   plannedTp2 = NormalizeDouble(plannedTp2, g_digits);

   double margin = 0.0;
   if(!OrderCalcMargin(orderType, Symbol(), lots, entryPrice, margin))
   {
      Print("PrecisionSniperEA: 保證金預檢失敗，放棄下單。");
      return;
   }
   if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      Print("PrecisionSniperEA: 可用保證金不足，required=", margin, " free=", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
      return;
   }
   
   // 5. 送出訂單 (以最終 TP3 作為伺服器 TP，TP1/2 由 EA 動態分批離場或移動止損)
   bool success = false;
   if(type == POSITION_TYPE_BUY)
   {
      success = trade.Buy(lots, Symbol(), ask, slPrice, tp3Price, InpComment);
   }
   else
   {
      success = trade.Sell(lots, Symbol(), bid, slPrice, tp3Price, InpComment);
   }
   
   if(success && TradeRetcodeOK("開倉"))
   {
      // 只在 broker 接受交易後才記錄全域開倉數據，避免失敗訂單留下假狀態。
      g_entryPrice  = entryPrice;
      g_slPrice     = slPrice;
      g_riskVal     = riskVal;
      g_tp1Price    = plannedTp1;
      g_tp2Price    = plannedTp2;
      g_tp3Price    = tp3Price;
      g_positionDir = (type == POSITION_TYPE_BUY) ? 1 : -1;
      g_tp1Hit      = false;
      g_tp2Hit      = false;
      Print("PrecisionSniperEA: 開倉成功！手數: ", lots, " 入場價: ", entryPrice, " 止損價: ", slPrice, " 最終止盈: ", tp3Price);
   }
   else
   {
      Print("PrecisionSniperEA: 開倉失敗！錯誤代碼: ", trade.ResultRetcodeDescription());
      ResetState();
   }
}

//====================================================================
// 移動止損與分批止盈動態管理 (ManagePositionExits)
//====================================================================
void ManagePositionExits()
{
   // 搜尋當前 EA 的專屬持倉
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         double currentVol = PositionGetDouble(POSITION_VOLUME);
         double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL   = PositionGetDouble(POSITION_SL);
         double currentTP   = PositionGetDouble(POSITION_TP);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double price = (posType == POSITION_TYPE_BUY) ? bid : ask;
         
         // 狀態恢復與容錯：若 EA 重啟，則根據持倉與預設比例動態還原價格水平
         if(g_positionDir == 0 || MathAbs(g_entryPrice - openPrice) > g_point)
         {
            g_entryPrice  = openPrice;
            g_slPrice     = currentSL;
            g_riskVal     = MathAbs(openPrice - currentSL);
            
            if(g_riskVal <= 0) // 防禦性除零保護
            {
               double atrBuf[1];
               if(CopyBuffer(hATR, 0, 1, 1, atrBuf) > 0) g_riskVal = atrBuf[0] * C_SLMult;
               else g_riskVal = 200 * g_point;
            }
            
            g_positionDir = (posType == POSITION_TYPE_BUY) ? 1 : -1;
            g_tp1Price    = openPrice + g_positionDir * g_riskVal * TP1_RR;
            g_tp2Price    = openPrice + g_positionDir * g_riskVal * TP2_RR;
            g_tp3Price    = openPrice + g_positionDir * g_riskVal * TP3_RR;
            
            g_tp1Price    = NormalizeDouble(g_tp1Price, g_digits);
            g_tp2Price    = NormalizeDouble(g_tp2Price, g_digits);
            g_tp3Price    = NormalizeDouble(g_tp3Price, g_digits);

            // 依止損已被推進的位置推斷分批階段 (僅 UseTrail 時 SL 會移動可推斷；
            // 非 trailing 模式重啟無法由 SL 還原，保守視為尚未分批，最差只是少一次提早出場)
            if(UseTrail)
            {
               if(posType == POSITION_TYPE_BUY)
               {
                  g_tp2Hit = (currentSL >= g_tp1Price - g_point);
                  g_tp1Hit = g_tp2Hit || (currentSL >= openPrice - g_point);
               }
               else
               {
                  g_tp2Hit = (currentSL > 0 && currentSL <= g_tp1Price + g_point);
                  g_tp1Hit = g_tp2Hit || (currentSL > 0 && currentSL <= openPrice + g_point);
               }
            }
            else { g_tp1Hit = false; g_tp2Hit = false; }
         }
         
         double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
         double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
         if(step <= 0.0 || minLot <= 0.0)
         {
            Print("PrecisionSniperEA: broker volume step/min lot 無效，略過出場管理。");
            continue;
         }
         
         //=================================================================
         // 多單出口管理 (Buy Position Management)
         //=================================================================
         if(posType == POSITION_TYPE_BUY)
         {
            // ── 第一階段：觸及 TP1 ──
            if(price >= g_tp1Price && !g_tp1Hit)
            {
               Print("PrecisionSniperEA: 價格觸及 TP1 (", g_tp1Price, ")。");
               bool stageOK = true;

               // 1. 移動止損至保本價 (Breakeven)
               if(UseTrail)
               {
                  stageOK = ModifyPositionChecked(ticket, openPrice, currentTP, "TP1 移動止損至保本");
                  if(stageOK) Print("PrecisionSniperEA: 止損已移動至保本位 (", openPrice, ")。");
               }

               // 2. 分批離場 1/3 手數
               if(stageOK && InpPartialExit)
               {
                  double closeVol = MathFloor((currentVol / 3.0) / step) * step;
                  if(closeVol < minLot) closeVol = minLot;
                  if(closeVol < currentVol)
                  {
                     stageOK = ClosePartialChecked(ticket, closeVol, "TP1 分批平倉");
                     if(stageOK) Print("PrecisionSniperEA: TP1 分批平倉 1/3 手數 (", closeVol, " Lots)。");
                  }
               }
               if(stageOK) g_tp1Hit = true;
            }

            // ── 第二階段：觸及 TP2 ──
            else if(price >= g_tp2Price && g_tp1Hit && !g_tp2Hit)
            {
               Print("PrecisionSniperEA: 價格觸及 TP2 (", g_tp2Price, ")。");
               bool stageOK = true;

               // 1. 移動止損至 TP1 鎖定利潤
               if(UseTrail)
               {
                  stageOK = ModifyPositionChecked(ticket, g_tp1Price, currentTP, "TP2 移動止損至 TP1");
                  if(stageOK) Print("PrecisionSniperEA: 止損已移至 TP1 鎖利 (", g_tp1Price, ")。");
               }

               // 2. 分批離場剩餘手數的 1/2 (即初始總手數的另 1/3)
               if(stageOK && InpPartialExit)
               {
                  double closeVol = MathFloor((currentVol / 2.0) / step) * step;
                  if(closeVol < minLot) closeVol = minLot;
                  if(closeVol < currentVol)
                  {
                     stageOK = ClosePartialChecked(ticket, closeVol, "TP2 分批平倉");
                     if(stageOK) Print("PrecisionSniperEA: TP2 分批平倉剩餘的一半 (", closeVol, " Lots)。");
                  }
               }
               if(stageOK) g_tp2Hit = true;
            }

            // ── 第三階段：觸及 TP3 ──
            // 價格若達到 TP3，將由伺服器端挂單 TP3 自動全平。此處主動全平防止滑點。
            else if(price >= g_tp3Price)
            {
               Print("PrecisionSniperEA: 價格觸及最終目標 TP3 (", g_tp3Price, ")，全部平倉離場。");
               if(ClosePositionChecked(ticket, "TP3 全部平倉"))
                  ResetState();
            }
         }
         
         //=================================================================
         // 空單出口管理 (Sell Position Management)
         //=================================================================
         else if(posType == POSITION_TYPE_SELL)
         {
            // ── 第一階段：觸及 TP1 ──
            if(price <= g_tp1Price && !g_tp1Hit)
            {
               Print("PrecisionSniperEA: 價格觸及 TP1 (", g_tp1Price, ")。");
               bool stageOK = true;

               if(UseTrail)
               {
                  stageOK = ModifyPositionChecked(ticket, openPrice, currentTP, "TP1 移動止損至保本");
                  if(stageOK) Print("PrecisionSniperEA: 止損已移動至保本位 (", openPrice, ")。");
               }

               if(stageOK && InpPartialExit)
               {
                  double closeVol = MathFloor((currentVol / 3.0) / step) * step;
                  if(closeVol < minLot) closeVol = minLot;
                  if(closeVol < currentVol)
                  {
                     stageOK = ClosePartialChecked(ticket, closeVol, "TP1 分批平倉");
                     if(stageOK) Print("PrecisionSniperEA: TP1 分批平倉 1/3 手數 (", closeVol, " Lots)。");
                  }
               }
               if(stageOK) g_tp1Hit = true;
            }

            // ── 第二階段：觸及 TP2 ──
            else if(price <= g_tp2Price && g_tp1Hit && !g_tp2Hit)
            {
               Print("PrecisionSniperEA: 價格觸及 TP2 (", g_tp2Price, ")。");
               bool stageOK = true;

               if(UseTrail)
               {
                  stageOK = ModifyPositionChecked(ticket, g_tp1Price, currentTP, "TP2 移動止損至 TP1");
                  if(stageOK) Print("PrecisionSniperEA: 止損已移至 TP1 鎖利 (", g_tp1Price, ")。");
               }

               if(stageOK && InpPartialExit)
               {
                  double closeVol = MathFloor((currentVol / 2.0) / step) * step;
                  if(closeVol < minLot) closeVol = minLot;
                  if(closeVol < currentVol)
                  {
                     stageOK = ClosePartialChecked(ticket, closeVol, "TP2 分批平倉");
                     if(stageOK) Print("PrecisionSniperEA: TP2 分批平倉剩餘的一半 (", closeVol, " Lots)。");
                  }
               }
               if(stageOK) g_tp2Hit = true;
            }

            // ── 第三階段：觸及 TP3 ──
            else if(price <= g_tp3Price)
            {
               Print("PrecisionSniperEA: 價格觸及最終目標 TP3 (", g_tp3Price, ")，全部平倉離場。");
               if(ClosePositionChecked(ticket, "TP3 全部平倉"))
                  ResetState();
            }
         }
      }
   }
}

//====================================================================
// 常規交易輔助函數 (Helpers)
//====================================================================
bool HasPosition(ENUM_POSITION_TYPE type)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol() &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetInteger(POSITION_TYPE) == type)
      {
         return true;
      }
   }
   return false;
}

bool ClosePositions(ENUM_POSITION_TYPE type)
{
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetInteger(POSITION_TYPE) == type)
      {
         Print("PrecisionSniperEA: 反向信號觸發平倉。平倉單號: ", ticket);
         if(!ClosePositionChecked(ticket, "反向信號平倉"))
            allClosed = false;
      }
   }
   if(!HasPosition(POSITION_TYPE_BUY) && !HasPosition(POSITION_TYPE_SELL))
   {
      ResetState();
   }
   if(HasPosition(type))
      allClosed = false;
   return allClosed;
}

void ResetState()
{
   g_entryPrice   = 0;
   g_slPrice      = 0;
   g_tp1Price     = 0;
   g_tp2Price     = 0;
   g_tp3Price     = 0;
   g_riskVal      = 0;
   g_positionDir  = 0;
   g_tp1Hit       = false;
   g_tp2Hit       = false;
}

//====================================================================
// EA 面板繪製函數 (Graphical Panel UI)
//====================================================================
void CreateEAPanel()
{
   int X = 10, Y = 360, W = 290, H = 20, sep = 2;
   color C_TITLE_BG = C'10,25,50';
   color C_TITLE_FG = C'255,200,50';
   color C_PANEL_BG = C'18,22,35';
   color C_BORDER   = C'60,70,100';
   
   // 1. 面板標題列
   MakeRect("PSEA_Title_BG", X, Y, W, 24, C_TITLE_BG, C_TITLE_FG);
   MakeTxt("PSEA_Title_TX", X+8, Y+5, "PRECISION SNIPER EA", C_TITLE_FG, 10, "Arial Bold");
   MakeTxt("PSEA_Title_VER", X+220, Y+7, "[v1.20]", C'180,180,180', 7, "Arial");
   Y += 27;
   
   // 2. 交易狀態列
   MakeRect("PSEA_State_BG", X, Y, W, H+4, C_PANEL_BG, C_BORDER);
   MakeTxt("PSEA_State_TX", X+8, Y+5, "● EA STATUS: READY", C'80,220,100', 9, "Arial Bold");
   Y += H+8;
   
   // 3. 數據行範本
   CreateRow("PSEA_Row_1", X, Y, W, H, "Lots Mode", "Fixed 0.10", C'220,220,220'); Y += H+sep;
   CreateRow("PSEA_Row_2", X, Y, W, H, "Total Trades", "0", C'220,220,220'); Y += H+sep;
   CreateRow("PSEA_Row_3", X, Y, W, H, "Active Trade", "None", C'150,150,150'); Y += H+sep;
   CreateRow("PSEA_Row_4", X, Y, W, H, "Current PnL", "$ 0.00", C'150,150,150'); Y += H+sep;
   CreateRow("PSEA_Row_5", X, Y, W, H, "Dynamic Trls", "Breakeven / TP1 / TP2", C'255,160,0');
   
   ChartRedraw(0);
}

void CreateRow(string id, int x, int y, int w, int h, string label, string value, color valClr)
{
   color C_PANEL_BG = C'18,22,35';
   color C_BORDER   = C'50,55,75';
   MakeRect(id+"_BG", x, y, w, h, C_PANEL_BG, C_BORDER);
   MakeTxt(id+"_L", x+8, y+4, label, C'160,170,190', 7, "Arial");
   MakeTxt(id+"_V", x+105, y+4, value, valClr, 8, "Arial Bold");
}

void UpdateEAPanel()
{
   // 動態更新面板數值
   string lotsMode = InpUseRiskSize ? ("Risk " + DoubleToString(InpRiskPercent, 1) + "%") : ("Fixed " + DoubleToString(InpLots, 2));
   color lotsClr = InpUseRiskSize ? C'80,180,255' : C'220,220,220';
   SetVal("PSEA_Row_1_V", lotsMode, lotsClr);
   
   // 計算持倉數據
   int openCount = 0;
   double totLots = 0;
   double floatingPnL = 0;
   string activeTradeStr = "None";
   color activeClr = C'150,150,150';
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == Symbol() && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         openCount++;
         totLots += PositionGetDouble(POSITION_VOLUME);
         floatingPnL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         
         ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pType == POSITION_TYPE_BUY)
         {
            activeTradeStr = "LONG " + DoubleToString(totLots, 2) + " Lots";
            activeClr = C'80,220,100';
         }
         else
         {
            activeTradeStr = "SHORT " + DoubleToString(totLots, 2) + " Lots";
            activeClr = C'255,80,80';
         }
      }
   }
   
   SetVal("PSEA_Row_3_V", activeTradeStr, activeClr);
   
   // 浮動盈虧更新
   string pnlStr = "$ " + DoubleToString(floatingPnL, 2);
   color pnlClr = (floatingPnL > 0) ? C'80,220,100' : (floatingPnL < 0) ? C'255,80,80' : C'150,150,150';
   SetVal("PSEA_Row_4_V", pnlStr, pnlClr);
   
   // 更新 EA STATUS
   string statusStr = "● EA STATUS: ACTIVE";
   color statusClr = C'80,180,255';
   if(openCount > 0)
   {
      statusStr = "● EA STATUS: POSITION IN PLAY";
      statusClr = C'255,160,0';
   }
   ObjectSetString(0, "PSEA_State_TX", OBJPROP_TEXT, statusStr);
   ObjectSetInteger(0, "PSEA_State_TX", OBJPROP_COLOR, statusClr);
   
   ChartRedraw(0);
}

// 輔助畫圖函數
void MakeRect(string name, int x, int y, int w, int h, color bg, color border)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      border);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
}

void MakeTxt(string name, int x, int y, string txt, color col, int sz, string font)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  sz);
   if(font != "") ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_BACK,      false);
}

void SetVal(string name, string val, color col)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, val);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   }
}

//====================================================================
// 優化適應度函數 (OnTester) — 供 Strategy Tester 參數優化排序使用
//====================================================================
// 目標：在「回報 / 相對回撤」的基礎上兼顧穩定度 (Profit Factor)，
//       並要求最低交易樣本數以抑制過擬合 (overfitting)。
double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return 0.0;            // 樣本不足：不予採納，避免過擬合

   double profit = TesterStatistics(STAT_PROFIT);
   if(profit <= 0) return 0.0;            // 不獲利的組合直接淘汰

   double dd = TesterStatistics(STAT_EQUITY_DDREL_PERCENT); // 相對淨值回撤 %
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);

   double fitness = (dd > 0) ? (profit / dd) : profit;      // 回報 / 回撤
   fitness *= MathMin(pf, 5.0);                             // 兼顧穩定度，封頂避免極端值主導
   return fitness;
}
//+------------------------------------------------------------------+
