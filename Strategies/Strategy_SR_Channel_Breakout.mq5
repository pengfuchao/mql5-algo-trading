//+------------------------------------------------------------------+
//|                              Strategy_SR_Channel_Breakout.mq5    |
//|                                                                  |
//|  對接 Indicators/Support_Resistance_Channels.mq5 的 S/R EA。       |
//|  讀取指標的 Breakout / Bounce 訊號 buffer (已收盤棒)，             |
//|  支援順勢突破、支撐/壓力反彈或兩者混合，ATR 止損 + RR 止盈。       |
//+------------------------------------------------------------------+
//
// 已知限制與未來優化方向（2026-06-25 review）
// -------------------------------------------------------------------
// 1. MagicNumber ownership
//    - 目前未禁止 InpMagic=0；MT5 人工交易通常使用 MagicNumber 0。
//    - 若設為 0，EA 可能把人工部位視為自有部位並納入計數或反向平倉。
//    - 未來應在 OnInit() 拒絕 InpMagic=0，或建立更明確的 ownership policy。
//
// 2. Risk sizing 精度
//    - 目前以 SYMBOL_TRADE_TICK_VALUE / SYMBOL_TRADE_TICK_SIZE 估算 SL 金額風險。
//    - 對部分 CFD、期貨、交叉貨幣或特殊計價商品，估算值可能偏離帳戶貨幣
//      中的實際損失。
//    - 未來建議使用 OrderCalcProfit()，分別以 Buy/Sell、實際 entry 與 SL
//      計算 1 lot 的預期損失，再由風險金額反推手數。
//
// 3. Netting/Exchange account ownership
//    - 現行防護以 position 的 POSITION_MAGIC 判斷是否屬於本 EA。
//    - Netting position 可能由多筆不同 MagicNumber 或人工 deals 合併，
//      單一 POSITION_MAGIC 無法完整證明整個淨部位的 ownership。
//    - 最安全的未來方案是限定 Hedging account，或要求 Netting symbol
//      完全由本 EA 獨占，並以 deal history 建立更嚴格的來源驗證。
//
// 4. 市價成交、滑點與成交後驗證
//    - lots、SL、TP 依送單前的 Bid/Ask 計算；實際成交價可能因滑點不同。
//    - 成交後的真實風險可能偏離 InpRiskPercent，SL/TP 也可能需要重新驗證。
//    - 未來可加入 OrderCheck()，並在成交後核對 deal price、position volume、
//      SL/TP 與實際帳戶貨幣風險；若超限，採取明確的 fail-safe 行為。
//
// 5. Fixed-lot normalization
//    - 固定手數模式目前會將低於 broker minimum 的正數提高到 minimum lot。
//    - 這是有效成交量正規化，但可能高於使用者原始設定。
//    - 未來可改成嚴格模式：設定低於 minimum 或不符合 volume step 時拒絕交易，
//      或至少輸出 requested lots 與 normalized lots 的明確警告。
//
// 6. 上游 Indicator 與 TradingView 差異
//    - Support_Resistance_Channels.mq5 採已收盤棒、每根新棒重建通道；
//      Pine 原版使用 stateful pivot arrays，且只在新 pivot 確認時重建通道。
//    - 因此兩者不是 signal-identical，MT5 與 TradingView breakout 日期可能不同。
//    - 未來若追求 Pine 等價性，需另行設計 stateful 模式；若供 EA 使用，
//      應保留 causal/closed-bar 模式並以獨立選項明確區分。
//
// 以上為後續 hardening / research 項目，不代表目前已完成實作或驗證。
// 在 live trading 前仍需 Strategy Tester、demo forward test、不同商品與
// broker constraints、spread、commission、slippage及 market regime 驗證。
// -------------------------------------------------------------------
#property copyright "Jimmy"
#property version   "1.00"

#include <Trade\Trade.mqh>

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

enum ENUM_SR_SIGNAL_MODE
  {
   SIG_BREAKOUT = 0,   // Breakout only
   SIG_BOUNCE   = 1,   // Bounce/rejection only
   SIG_BOTH     = 2,   // Breakout + bounce
   SIG_RETEST   = 3    // SBR/RBS retest only
  };

//=== 指標參數 (順序必須與 Support_Resistance_Channels.mq5 的 input 宣告一致) ===
input group "S/R Indicator"
input string          InpIndicatorName  = "Support_Resistance_Channels"; // iCustom 路徑 (相對 MQL5\Indicators)
input int             InpPivotPeriod    = 10;            // Pivot Period
input ENUM_SR_SOURCE  InpSourceMode     = SRC_HIGHLOW;   // Source
input int             InpChannelWidthPct= 5;             // Max Channel Width %
input int             InpMinStrength    = 1;             // Minimum Strength
input int             InpMaxNumSR       = 6;             // Maximum Number of S/R
input int             InpLoopback       = 290;           // Loopback Period
input ENUM_SR_WIDTH_MODE InpChannelWidthMode = WIDTH_RANGE_PCT; // Channel Width Mode
input int             InpATRLen         = 14;            // ATR Length for channel width
input double          InpATRMult        = 0.3;           // ATR Multiplier for channel width
input bool            InpUseVolumeFilter= false;         // Confirm breakouts by relative tick volume
input int             InpVolMaLen       = 20;            // Tick volume MA length
input double          InpVolMult        = 1.0;           // Tick volume multiplier
input double          InpRetestTolerATR = 0.10;          // Retest tolerance = ATR multiplier
input int             InpRetestExpiryBars = 20;          // Retest flip expiry bars

input group "Signal"
input ENUM_SR_SIGNAL_MODE InpSignalMode = SIG_BREAKOUT;  // Signal mode

//=== 交易設定 ===
input group "Trade"
input ulong           InpMagic          = 770010;        // Magic Number
input ulong           InpDeviation      = 20;            // 允許滑點 (points)
input double          InpMaxSpreadPts   = 30.0;          // 最大點差 (points)，0=不檢查
input bool            InpCloseOnReverse = true;          // 反向訊號先平倉
input bool            InpOnePosition    = true;          // 同方向僅持一張
input int             InpMaxPositions   = 5;             // 同方向最大持倉數 (OnePosition=false 時生效)
input bool            InpTradeOnFirstBar= false;         // 掛載後是否立即依上一根訊號交易

//=== 倉位與風險 ===
input group "Sizing & Risk"
input bool            InpUseRiskSizing  = true;          // 以風險% + SL 距離計算手數
input double          InpRiskPercent    = 1.0;           // 每筆風險佔淨值 %
input double          InpFixedLots      = 0.10;          // 固定手數 (UseRiskSizing=false)
input int             InpATRPeriod      = 14;            // ATR 週期 (止損距離)
input double          InpSLMultiple     = 1.5;           // 止損 = ATR × 此倍數
input double          InpTPRatio        = 2.0;           // 止盈 = SL 距離 × 此倍數 (RR)，0=不設

//=== 最佳化評分設定 ===
input group "Optimization"
input int             InpOptMinTrades        = 30;       // OnTester: minimum trades
input double          InpOptMinProfitFactor  = 1.20;     // OnTester: reject PF below this
input double          InpOptMaxDDPercent     = 20.0;     // OnTester: reject equity DD% above this, <=0 disables
input int             InpOptTradeBoostCap    = 120;      // OnTester: cap sqrt(trades) boost to avoid overtrading bias

//--- 全域
CTrade   trade;
int      srHandle  = INVALID_HANDLE;
int      atrHandle = INVALID_HANDLE;
datetime lastBar   = 0;
ENUM_ACCOUNT_MARGIN_MODE marginMode = ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;

//+------------------------------------------------------------------+
//| 手數正規化                                                       |
//+------------------------------------------------------------------+
//   回傳 <= 0 表示成交量限制無效 (fail closed，呼叫端不得交易)
double NormalizeLots(double lots)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0 || maxLot <= 0.0 || step <= 0.0)
     {
      PrintFormat("成交量限制無效 min=%.4f max=%.4f step=%.4f，fail closed", minLot, maxLot, step);
      return 0.0;
     }

   // 向下對齊 step (加微小容差避免浮點誤差誤砍一個 step)
   lots = MathFloor(lots / step + 1e-7) * step;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   // 高精度正規化僅去除浮點殘差，保留合法 step 倍數 (含 0.25/0.5 等非十進位 step)
   return NormalizeDouble(lots, 8);
  }

//+------------------------------------------------------------------+
//| 價格對齊 broker tick size — 方向感知 (避免量化使距離縮短)         |
//|   AlignDown：向下對齊；AlignUp：向上對齊                          |
//+------------------------------------------------------------------+
double AlignDown(double price)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0) ts = _Point;
   if(ts <= 0) return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathFloor(price / ts + 1e-7) * ts, _Digits);
  }
double AlignUp(double price)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0) ts = _Point;
   if(ts <= 0) return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathCeil(price / ts - 1e-7) * ts, _Digits);
  }

//+------------------------------------------------------------------+
//| 依 SL 距離與風險% 計算手數                                        |
//|   回傳 <= 0 表示「不應交易」(風險設定為 0，或最小手數已超過上限)  |
//+------------------------------------------------------------------+
double LotsByRisk(double slDistance)
  {
   if(!InpUseRiskSizing)
     {
      if(InpFixedLots <= 0.0) { Print("InpFixedLots<=0，跳過進場"); return 0.0; }
      return NormalizeLots(InpFixedLots);
     }

   if(InpRiskPercent <= 0.0)
     {
      Print("InpRiskPercent<=0，跳過進場");
      return 0.0;
     }

   // Risk 模式：任一必要資料無效一律 fail closed (不回退固定手數，避免靜默放大風險)
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   if(slDistance <= 0 || tickValue <= 0 || tickSize <= 0 || equity <= 0)
     {
      PrintFormat("風險計算資料無效 slDist=%.5f tickVal=%.5f tickSize=%.5f equity=%.2f，略過進場",
                  slDistance, tickValue, tickSize, equity);
      return 0.0;
     }

   double valuePerPricePerLot = tickValue / tickSize;       // 每 1.0 價格波動每手金額
   double riskPerLot = slDistance * valuePerPricePerLot;    // 每手在 SL 距離下的金額風險
   if(riskPerLot <= 0)
     {
      Print("riskPerLot<=0，略過進場");
      return 0.0;
     }

   double riskAmount = (InpRiskPercent / 100.0) * equity;

   double lots       = NormalizeLots(riskAmount / riskPerLot);
   if(lots <= 0.0) return 0.0;                               // 成交量限制無效 → fail closed
   double actualRisk = lots * riskPerLot;
   // 最小手數/步進向上夾擠導致實際風險超過設定上限時，停止交易而非放大風險
   if(actualRisk > riskAmount * 1.0001)
     {
      PrintFormat("最小手數 %.2f 風險 %.2f 超過上限 %.2f (%.2f%% equity)，略過進場",
                  lots, actualRisk, riskAmount, InpRiskPercent);
      return 0.0;
     }
   return lots;
  }

//+------------------------------------------------------------------+
//| 計算本 EA (symbol+magic) 的多空持倉數                            |
//+------------------------------------------------------------------+
void CountPositions(int &buyCount, int &sellCount)
  {
   buyCount = 0; sellCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)  buyCount++;
      if(type == POSITION_TYPE_SELL) sellCount++;
     }
  }

//+------------------------------------------------------------------+
//| 平掉本 EA 指定方向的所有持倉                                      |
//|   回傳 true 表示全部成功送出且未被拒，false 表示至少一筆失敗      |
//+------------------------------------------------------------------+
bool CloseByType(const ENUM_POSITION_TYPE wantType)
  {
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetInteger(POSITION_TYPE) != wantType) continue;
      if(!trade.PositionClose(ticket))
        {
         allClosed = false;
         PrintFormat("PositionClose 失敗 ticket=%I64u: retcode=%u %s",
                     ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }
   return allClosed;
  }

//+------------------------------------------------------------------+
//| 交易環境檢查 (terminal/account/symbol 是否允許交易、是否開盤)     |
//+------------------------------------------------------------------+
//   方向感知：Buy 拒 SHORTONLY、Sell 拒 LONGONLY，並拒 DISABLED/CLOSEONLY
bool CanTrade(const bool isBuy)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))         return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))                   return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))           return false;
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   if(isBuy  && mode == SYMBOL_TRADE_MODE_SHORTONLY) return false;
   if(!isBuy && mode == SYMBOL_TRADE_MODE_LONGONLY)  return false;
   return true;
  }

//+------------------------------------------------------------------+
//| 開倉前保證金檢查 (H：無法可靠計算時 fail closed)                  |
//+------------------------------------------------------------------+
bool HasEnoughMargin(const ENUM_ORDER_TYPE type, const double lots, const double price)
  {
   double margin = 0.0;
   if(!OrderCalcMargin(type, _Symbol, lots, price, margin))
     {
      PrintFormat("OrderCalcMargin 失敗 (err=%d)，fail closed", GetLastError());
      return false;
     }
   return (AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= margin);
  }

//+------------------------------------------------------------------+
//| 下單結果記錄 (H：區分 deal completed / accepted / 待確認)         |
//+------------------------------------------------------------------+
void LogTradeResult(const string ctx, const bool sent)
  {
   uint rc = trade.ResultRetcode();
   if(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL)
      PrintFormat("%s 成交: deal=%I64u order=%I64u vol=%.2f price=%.5f",
                  ctx, trade.ResultDeal(), trade.ResultOrder(), trade.ResultVolume(), trade.ResultPrice());
   else if(rc == TRADE_RETCODE_PLACED)
      PrintFormat("%s 已受理(掛單/待確認): order=%I64u retcode=%u", ctx, trade.ResultOrder(), rc);
   else
      PrintFormat("%s 失敗: sent=%s retcode=%u %s err=%d",
                  ctx, (sent ? "true" : "false"), rc, trade.ResultRetcodeDescription(), GetLastError());
  }

//+------------------------------------------------------------------+
//| 偵測候選新 K 棒 (僅偵測，不在此標記為已處理)                      |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t[1];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, t) < 1) return false;
   return (t[0] != lastBar);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   // 輸入驗證 → 無效設定直接拒絕載入 (fail fast)
   if(InpUseRiskSizing && InpRiskPercent <= 0.0)
     { Print("InpRiskPercent 必須 > 0 (risk sizing 模式)");  return(INIT_PARAMETERS_INCORRECT); }
   if(!InpUseRiskSizing && InpFixedLots <= 0.0)
     { Print("InpFixedLots 必須 > 0 (固定手數模式)");        return(INIT_PARAMETERS_INCORRECT); }
   if(InpATRPeriod < 1)
     { Print("InpATRPeriod 必須 >= 1");                      return(INIT_PARAMETERS_INCORRECT); }
   if(InpSLMultiple <= 0.0)
     { Print("InpSLMultiple 必須 > 0");                      return(INIT_PARAMETERS_INCORRECT); }
   if(InpTPRatio < 0.0)
     { Print("InpTPRatio 不可為負");                         return(INIT_PARAMETERS_INCORRECT); }
   if(InpMaxPositions < 1)
     { Print("InpMaxPositions 必須 >= 1");                   return(INIT_PARAMETERS_INCORRECT); }
   // Phase 1 新增參數驗證 (僅在相關模式啟用時檢查，避免誤拒未使用的參數)
   if(InpChannelWidthMode == WIDTH_ATR && InpATRLen < 1)
     { Print("InpATRLen 必須 >= 1 (ATR 寬度模式)");          return(INIT_PARAMETERS_INCORRECT); }
   if(InpChannelWidthMode == WIDTH_ATR && InpATRMult <= 0.0)
     { Print("InpATRMult 必須 > 0 (ATR 寬度模式)");          return(INIT_PARAMETERS_INCORRECT); }
   if(InpUseVolumeFilter && InpVolMaLen < 1)
     { Print("InpVolMaLen 必須 >= 1 (量過濾啟用時)");        return(INIT_PARAMETERS_INCORRECT); }
   if(InpUseVolumeFilter && InpVolMult < 0.0)
     { Print("InpVolMult 不可為負 (量過濾啟用時)");          return(INIT_PARAMETERS_INCORRECT); }
   if(InpSignalMode == SIG_RETEST && InpRetestTolerATR <= 0.0)
     { Print("InpRetestTolerATR 必須 > 0 (retest 模式)");     return(INIT_PARAMETERS_INCORRECT); }
   if(InpSignalMode == SIG_RETEST && InpRetestExpiryBars < 1)
     { Print("InpRetestExpiryBars 必須 >= 1 (retest 模式)");  return(INIT_PARAMETERS_INCORRECT); }
   if(InpOptMinTrades < 1)
     { Print("InpOptMinTrades 必須 >= 1");                    return(INIT_PARAMETERS_INCORRECT); }
   if(InpOptMinProfitFactor < 1.0)
     { Print("InpOptMinProfitFactor 必須 >= 1.0");            return(INIT_PARAMETERS_INCORRECT); }
   if(InpOptTradeBoostCap < 1)
     { Print("InpOptTradeBoostCap 必須 >= 1");                return(INIT_PARAMETERS_INCORRECT); }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);

   srHandle = iCustom(_Symbol, _Period, InpIndicatorName,
                      InpPivotPeriod, InpSourceMode, InpChannelWidthPct,
                      InpMinStrength, InpMaxNumSR, InpLoopback,
                      InpChannelWidthMode, InpATRLen, InpATRMult,
                      InpUseVolumeFilter, InpVolMaLen, InpVolMult,
                      InpRetestTolerATR, InpRetestExpiryBars);
   if(srHandle == INVALID_HANDLE)
     {
      PrintFormat("無法載入指標 '%s' (請確認已編譯且路徑正確), error=%d",
                  InpIndicatorName, GetLastError());
      return(INIT_FAILED);
     }

   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("無法載入 ATR 指標！");
      return(INIT_FAILED);
     }

   marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   PrintFormat("帳戶 margin mode = %s", EnumToString(marginMode));

   // M1：預設等待下一根新 K 棒才交易，避免掛載當下吃上一根 stale signal
   if(InpTradeOnFirstBar)
      lastBar = 0;
   else
     {
      datetime t[1];
      lastBar = (CopyTime(_Symbol, _Period, 0, 1, t) == 1) ? t[0] : 0;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(srHandle  != INVALID_HANDLE) IndicatorRelease(srHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // G：偵測候選新 K 棒；資料就緒前不更新 lastBar，暫時失敗時留待同根後續 tick 重試
   if(!IsNewBar()) return;
   datetime curBar[1];
   if(CopyTime(_Symbol, _Period, 0, 1, curBar) < 1) return;

   // 指標/ATR 計算就緒檢查 (暫時失敗 → 不標記已處理)
   if(BarsCalculated(srHandle) < 2 || BarsCalculated(atrHandle) < 2) return;

   bool useBreakout = (InpSignalMode == SIG_BREAKOUT || InpSignalMode == SIG_BOTH);
   bool useBounce   = (InpSignalMode == SIG_BOUNCE   || InpSignalMode == SIG_BOTH);
   bool useRetest   = (InpSignalMode == SIG_RETEST);

   double resArr[1] = {0.0}, supArr[1] = {0.0};
   double resBounceArr[1] = {0.0}, supBounceArr[1] = {0.0};
   double retestBuyArr[1] = {0.0}, retestSellArr[1] = {0.0};
   double atrArr[1];
   if(useBreakout && CopyBuffer(srHandle, 2, 1, 1, resArr) < 1) return;      // shift=1 已收盤棒
   if(useBreakout && CopyBuffer(srHandle, 3, 1, 1, supArr) < 1) return;
   if(useBounce && CopyBuffer(srHandle, 6, 1, 1, resBounceArr) < 1) return;
   if(useBounce && CopyBuffer(srHandle, 7, 1, 1, supBounceArr) < 1) return;
   if(useRetest && CopyBuffer(srHandle, 8, 1, 1, retestBuyArr) < 1) return;
   if(useRetest && CopyBuffer(srHandle, 9, 1, 1, retestSellArr) < 1) return;
   if(CopyBuffer(atrHandle, 0, 1, 1, atrArr) < 1) return;

   // 資料齊全 → 本根 K 棒標記為已處理 (即使無訊號或最終不下單，亦不於同根重評估)
   lastBar = curBar[0];

   bool breakoutBuy  = (resArr[0] > 0.0);         // 壓力向上突破 → 做多
   bool breakoutSell = (supArr[0] > 0.0);         // 支撐向下跌破 → 做空
   bool bounceBuy    = (supBounceArr[0] > 0.0);   // 支撐拒絕 → 做多
   bool bounceSell   = (resBounceArr[0] > 0.0);   // 壓力拒絕 → 做空
   bool retestBuy    = (retestBuyArr[0] > 0.0);    // RBS 回測守住 → 做多
   bool retestSell   = (retestSellArr[0] > 0.0);   // SBR 回測守住 → 做空
   bool buySig       = (useBreakout && breakoutBuy)  || (useBounce && bounceBuy)  || (useRetest && retestBuy);
   bool sellSig      = (useBreakout && breakoutSell) || (useBounce && bounceSell) || (useRetest && retestSell);
   if(!buySig && !sellSig) return;
   if(buySig && sellSig)   return;     // 同棒同時觸發 (罕見)，視為不明確不交易
   bool isBuy = buySig;
   string signalTag = "mixed";
   if(isBuy)
     {
      if((useBreakout && breakoutBuy) && !(useBounce && bounceBuy)) signalTag = "breakout";
      if((useBounce && bounceBuy) && !(useBreakout && breakoutBuy)) signalTag = "bounce";
      if(useRetest && retestBuy) signalTag = "retest";
     }
   else
     {
      if((useBreakout && breakoutSell) && !(useBounce && bounceSell)) signalTag = "breakout";
      if((useBounce && bounceSell) && !(useBreakout && breakoutSell)) signalTag = "bounce";
      if(useRetest && retestSell) signalTag = "retest";
     }

   // F/L6：方向感知交易環境檢查
   if(!CanTrade(isBuy)) { Print("目前不允許該方向交易 (mode/permission)，略過"); return; }

   // A：Netting/Exchange 帳戶下，若該 symbol 已存在「非本 EA」部位，禁止進場 (不干擾他人 exposure)
   if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
        {
         PrintFormat("Netting：%s 已存在非本 EA (magic=%I64d) 的部位，禁止進場以免干擾其 exposure",
                     _Symbol, PositionGetInteger(POSITION_MAGIC));
         return;
        }
     }

   double atr = atrArr[0];
   if(atr <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return;
   double spread = ask - bid;

   // 點差過濾
   if(InpMaxSpreadPts > 0)
     {
      double spreadPts = spread / _Point;
      if(spreadPts > InpMaxSpreadPts)
        {
         PrintFormat("點差 %.1f > 上限 %.1f，略過進場", spreadPts, InpMaxSpreadPts);
         return;
        }
     }

   // E/M2：broker 最低距離 = max(StopsLevel, FreezeLevel)，SL 距離下限再加 spread (對應側價格)
   double stopsLevel  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL)  * _Point;
   double freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double brokerMin   = MathMax(stopsLevel, freezeLevel);
   double slDist      = MathMax(atr * InpSLMultiple, brokerMin + spread);
   if(slDist <= 0) return;

   int buyCount, sellCount;
   CountPositions(buyCount, sellCount);
   int maxSameDir = InpOnePosition ? 1 : MathMax(1, InpMaxPositions); // L5：同方向上限

   //=== 做多 ===
   if(isBuy)
     {
      // H1：反向倉須確認全部關閉才進場
      if(InpCloseOnReverse && sellCount > 0)
        {
         CloseByType(POSITION_TYPE_SELL);
         CountPositions(buyCount, sellCount);
         if(sellCount > 0) { Print("反向(空)倉未全部關閉，略過本次進場"); return; }
        }
      if(buyCount >= maxSameDir) return;

      // E：Buy SL 向下對齊、TP 向上對齊 → 量化不會縮短距離
      double sl = AlignDown(ask - slDist);
      double tpDist = (InpTPRatio > 0) ? MathMax(slDist * InpTPRatio, brokerMin) : 0.0;
      double tp = (tpDist > 0) ? AlignUp(ask + tpDist) : 0.0;

      // 量化後重新驗證真實距離 (對應側價格)；不符 broker 最低要求則不下單
      if((bid - sl) < brokerMin) { PrintFormat("Buy SL 距離不足 (%.5f<%.5f)，略過", bid - sl, brokerMin); return; }
      if(tp > 0 && (tp - bid) < brokerMin) { Print("Buy TP 距離不足，略過"); return; }

      double lots = LotsByRisk(ask - sl);                           // 用量化後真實 SL 距離 sizing
      if(lots <= 0) return;                                         // H2/B：風險超限或資料無效 → 不交易
      if(!HasEnoughMargin(ORDER_TYPE_BUY, lots, ask)) { Print("可用保證金不足/無法計算，略過做多"); return; }

      bool sent = trade.Buy(lots, _Symbol, 0.0, sl, tp, "SRchan " + signalTag + " buy");
      LogTradeResult("Buy", sent);
     }
   //=== 做空 ===
   else
     {
      if(InpCloseOnReverse && buyCount > 0)
        {
         CloseByType(POSITION_TYPE_BUY);
         CountPositions(buyCount, sellCount);
         if(buyCount > 0) { Print("反向(多)倉未全部關閉，略過本次進場"); return; }
        }
      if(sellCount >= maxSameDir) return;

      // E：Sell SL 向上對齊、TP 向下對齊
      double sl = AlignUp(bid + slDist);
      double tpDist = (InpTPRatio > 0) ? MathMax(slDist * InpTPRatio, brokerMin) : 0.0;
      double tp = (tpDist > 0) ? AlignDown(bid - tpDist) : 0.0;

      if((sl - ask) < brokerMin) { PrintFormat("Sell SL 距離不足 (%.5f<%.5f)，略過", sl - ask, brokerMin); return; }
      if(tp > 0 && (ask - tp) < brokerMin) { Print("Sell TP 距離不足，略過"); return; }

      double lots = LotsByRisk(sl - bid);
      if(lots <= 0) return;
      if(!HasEnoughMargin(ORDER_TYPE_SELL, lots, bid)) { Print("可用保證金不足/無法計算，略過做空"); return; }

      bool sent = trade.Sell(lots, _Symbol, 0.0, sl, tp, "SRchan " + signalTag + " sell");
      LogTradeResult("Sell", sent);
     }
  }

//+------------------------------------------------------------------+
//| 自訂最佳化評分：PF/DD guardrails + capped sample-size boost       |
//+------------------------------------------------------------------+
double OnTester()
  {
   double netProfit    = TesterStatistics(STAT_PROFIT);
   double ddPercent    = TesterStatistics(STAT_EQUITYDD_PERCENT);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery     = TesterStatistics(STAT_RECOVERY_FACTOR);
   int    trades       = (int)TesterStatistics(STAT_TRADES);

   int minTrades = MathMax(1, InpOptMinTrades);
   if(trades < minTrades ||
      netProfit <= 0.0 ||
      ddPercent <= 0.0 ||
      recovery <= 0.0 ||
      profitFactor <= 0.0 ||
      !MathIsValidNumber(profitFactor) ||
      !MathIsValidNumber(recovery))
      return 0.0;

   double minPF = MathMax(1.0, InpOptMinProfitFactor);
   if(profitFactor < minPF)
      return 0.0;

   double maxDD = InpOptMaxDDPercent;
   if(maxDD > 0.0 && ddPercent > maxDD)
      return 0.0;

   int tradeCap = MathMax(minTrades, InpOptTradeBoostCap);
   double tradeBoost = MathSqrt((double)MathMin(trades, tradeCap));

   double ddPenalty = 1.0;
   if(maxDD > 0.0)
     {
      double ddRatio = MathMin(ddPercent / maxDD, 1.0);
      ddPenalty = 1.0 - 0.5 * ddRatio * ddRatio;
     }

   double pfEdge = profitFactor - minPF + 1.0;
   double score = recovery * pfEdge * tradeBoost * ddPenalty;
   if(score < 0.0 || !MathIsValidNumber(score)) score = 0.0;
   return score;
  }
//+------------------------------------------------------------------+
