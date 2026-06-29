# Strategies (交易策略 / EA)

本資料夾存放各類 MetaTrader 5 (MT5) 自動化交易策略 (Expert Advisors, EA)。這些策略涵蓋從基礎範本到進階演算法（如網格、馬丁格爾、海龜交易等），主要使用現代化的 `CTrade` 訂單管理；部分策略明確依賴 Hedging 帳戶行為，使用前應確認帳戶模式與經紀商交易限制。

## 檔案說明

以下為本資料夾內各個策略檔案的功能講解：

*   **`Strategy_Template_MT5.mq5`**
    *   **功能**: MT5 EA 開發標準範本。
    *   **說明**: 提供一個乾淨且標準的 EA 基礎架構，包含初始化 (OnInit)、反初始化 (OnDeinit)、跳動點事件 (OnTick) 的基礎模版。

*   **`Strategy_First_EA.mq5` / `Strategy_Second_EA.mq5`**
    *   **功能**: 基礎 EA 範例。
    *   **說明**: 適合新手的入門範例，展示了最基本的下單邏輯與架構。

*   **`Strategy_Hedging.mq5`**
    *   **功能**: 對沖 (Hedging) 策略。
    *   **說明**: 專為 MT5 對沖帳戶設計的策略，允許在同一商品上同時持有並管理多單與空單。

*   **`Strategy_Alligator_Force.mq5`**
    *   **功能**: 鱷魚線與強弱指標策略。
    *   **說明**: 結合 Bill Williams 的鱷魚線 (Alligator) 與 Force Index 進行趨勢判斷與進出場的策略。

*   **`Strategy_Modified_Alligator.mq5`**
    *   **功能**: 改良版鱷魚線策略。
    *   **說明**: 對傳統鱷魚線策略進行參數或邏輯上的優化與改良版本。

*   **`Strategy_Indicator_Resonance_Long.mq5`**
    *   **功能**: 指標共振策略 (多頭/做多專用)。
    *   **說明**: 當多個技術指標在特定週期上產生「共振」訊號時，觸發做多 (Buy) 交易的策略系統。

*   **`Strategy_Indicator_Resonance_Short.mq5`**
    *   **功能**: 指標共振策略 (空頭/做空專用)。
    *   **說明**: 邏輯與上方相同，但專門用於尋找做空 (Sell) 的共振訊號。

*   **`Strategy_MACD_Martingale.mq5`**
    *   **功能**: MACD 馬丁格爾策略。
    *   **說明**: 結合 MACD 指標的交易訊號，並在虧損時使用馬丁格爾 (Martingale) 資金管理法進行加倉攤平。

*   **`Strategy_Moving_Grid.mq5`**
    *   **功能**: 動態網格策略。
    *   **說明**: 依據市場波動動態調整網格間距與掛單位置的網格交易系統。

*   **`Strategy_Optimized_Moving_Grid.mq5`**
    *   **功能**: 優化版動態網格策略。
    *   **說明**: 在原有的動態網格基礎上，加入了更進階的風險控制或參數最佳化機制。

*   **`Strategy_Turtle_Trading.mq5`**
    *   **功能**: 海龜交易策略。
    *   **說明**: 經典的海龜交易法則實作，包含 55 棒唐奇安通道突破進場、ATR (N) 止損、每 0.5N 加倉（最多 MaxUnits 單位）以及 20 棒反向唐奇安通道追蹤止損出場。出場機制純粹依 ATR 止損與通道追蹤，符合海龜順勢吃大波段的精神（已移除會提前了結趨勢的利潤鎖定機制）。**倉位管理採正宗海龜 ATR 動態手數（`UseATRSizing`）：以 `Unit = RiskPercent% × 淨值 ÷ (N × 每點價值)` 計算每單位手數，使單一單位 1N 不利波動約等於帳戶淨值的 `RiskPercent`%（預設 1%），手數隨波動率與淨值自動縮放，避免固定手數造成的爆倉風險；關閉時則回退為固定 `Lots`。** **內建趨勢過濾（`UseTrendFilter`）：以長週期均線（預設 EMA 100）判斷市場體制，僅在收盤價站上均線時掛多單突破、跌破均線時掛空單突破，過濾震盪盤的逆勢假突破以提升賺賠比；趨勢轉向時自動撤除不再符合方向的既有掛單。** 掛單價與止損皆對齊經紀商最小停損距離 (StopsLevel) 以避免 [Invalid stops] 拒單，並在持倉確立後即時取消反向突破掛單以防多空對沖；ATR 採用前一根已收盤 K 棒取樣，追蹤止損加入容差比較避免冗餘修改。**內建 `OnTester` 自訂最佳化評分（恢復因子 × 獲利因子 × √交易筆數），並以 `OptMinTrades` 作為過擬合防護，引導策略測試器朝「高報酬、低回撤、樣本充足」的穩健參數收斂。**

*   **`EA_ML_SuperTrend.mq5`**
    *   **功能**: 自適應機器學習 SuperTrend 自動化交易智能交易系統 (EA)。
    *   **說明**: 對接 `Indicators/ML_SuperTrend.mq5` 的 Buffer `2`、`3`、`4` 取得 Buy、Sell 與 confidence 訊號，並使用已收盤 K 棒執行反轉交易。支援固定手數、ATR stop-distance 風險手數與 confidence 比例手數，搭配 ATR 初始 SL/TP 及 SuperTrend line trailing stop。
    *   **使用限制**: Confidence 是指標的 adaptive score，不是經校準的真實勝率；使用前必須確認 `iCustom` 路徑、參數順序、指標已編譯，並在 Strategy Tester 納入 spread、commission、slippage 與不同市場狀態。

*   **`Strategy_SR_Channel_Breakout.mq5`**
    *   **功能**: 支撐/壓力通道 EA，可交易順勢突破、支撐/壓力反彈、SBR/RBS 回測進場，或突破+反彈混合。
    *   **訊號來源**: 透過 `iCustom` 對接 `Indicators/Support_Resistance_Channels.mq5`，讀取已收盤 K 棒 (`shift = 1`) 的 Buffer `2` (Resistance Broken)、Buffer `3` (Support Broken)、Buffer `6` (Resistance Bounce)、Buffer `7` (Support Bounce)、Buffer `8` (Retest Buy) 與 Buffer `9` (Retest Sell)。`iCustom` 計算參數順序為 `PivotPeriod, Source, ChannelWidthPct, MinStrength, MaxNumSR, Loopback, ChannelWidthMode, ATRLen, ATRMult, UseVolumeFilter, VolMaLen, VolMult, RetestTolerATR, RetestExpiryBars`，使用前必須確認指標已編譯且路徑 (`InpIndicatorName`) 正確。
    *   **進場與過濾**: `InpSignalMode=SIG_BREAKOUT` 時維持舊版邏輯：壓力向上突破 → 做多、支撐向下跌破 → 做空。`SIG_BOUNCE` 時改用反彈邏輯：支撐拒絕 → 做多、壓力拒絕 → 做空。`SIG_BOTH` 同時接受突破與反彈兩類訊號。`SIG_RETEST` 只交易順勢 SBR/RBS 回測：Retest Buy → 做多、Retest Sell → 做空。若同一根已收盤 K 棒同時出現多空訊號，視為不明確並跳過。Phase 1 新增 `InpUseVolumeFilter` 會在指標端抑制低 tick-volume breakout，`InpChannelWidthMode=WIDTH_ATR` 會改變上游 channel 幾何；兩者預設皆保留舊版 breakout 行為。EA 僅在新 K 棒評估，並以最大點差過濾。可選同方向僅持一張 (`InpOnePosition`) 或限制同方向最大持倉數 (`InpMaxPositions`)；反向訊號先平倉，且**確認反向倉全部關閉後才允許新進場** (避免平倉失敗造成多空對鎖/淨倉錯誤)。下單前以方向感知方式檢查 symbol trade mode (Buy 拒 `SHORTONLY`、Sell 拒 `LONGONLY`，並拒 `DISABLED`/`CLOSEONLY`) 與 terminal/account 權限。
    *   **帳戶 ownership (Netting vs Hedging)**: Hedging 帳戶以 symbol + MagicNumber 管理各自部位。**Netting/Exchange 帳戶下，若該 symbol 已存在「非本 EA MagicNumber」的部位 (其他策略或人工單)，EA 一律禁止新進場並記錄原因**，絕不關閉、修改或反轉非本 EA 的 exposure；無法判定 ownership 時 fail closed。
    *   **倉位與止損**: 止損採 ATR × 倍數，下限納入 `max(StopsLevel, FreezeLevel) + spread`；止盈以 RR 比例設定並套 broker 最低距離。**SL/TP 依方向量化** (Buy SL 向下、Buy TP 向上、Sell SL 向上、Sell TP 向下對齊 `SYMBOL_TRADE_TICK_SIZE`)，量化後重新驗證真實距離，不符即不下單。手數依淨值風險% 與「量化後真實 SL 距離」計算；**risk 模式下任一必要資料 (tick value/size、equity、SL 距離) 無效一律 fail closed (不回退固定手數)；最小手數實際風險超過上限、或 `InpRiskPercent<=0` 時略過進場而非放大手數**。`OnInit` 對無效 inputs (風險/固定手數<=0、ATRPeriod<1、SLMultiple<=0、TPRatio<0、MaxPositions<1) 回傳 `INIT_PARAMETERS_INCORRECT`。
    *   **掛載與同步**: 預設等待下一根新 K 棒才交易，避免掛載/重編譯當下吃上一根 stale signal (`InpTradeOnFirstBar=true` 可改為立即)。新 K 棒**僅在指標/ATR buffer (`BarsCalculated` + `CopyBuffer`) 成功讀取後才標記為已處理**；暫時讀取失敗會留待同根後續 tick 重試，避免永久漏訊號，同時保證同一根 K 棒不重複下單。保證金以 `OrderCalcMargin` 預檢，無法計算時 fail closed；下單後記錄 retcode/deal/order 並區分 deal completed / accepted / 失敗。
    *   **使用限制**: 上游指標為 **repaint** 且**與 TradingView 非 signal-identical** (通道每根重算、已收盤棒判定)，EA 僅信賴已收盤棒 (`shift=1`) 訊號，但回測與實盤行為仍可能因通道重算而不同。Bounce/rejection 屬逆勢訊號，需特別檢查強趨勢年份、交易成本、停損是否過早落在通道內，以及與 breakout regime 的互補性。Retest 交易數通常會少於裸突破，需跨商品合併樣本判斷是否真的改善假突破。FX volume filter 使用相對 tick volume，不是真實成交量；ATR channel width 是 mode switch，會影響所有下游訊號，不能與 Range% baseline 直接視為同一策略。**未實作自訂交易時段 (session) 排程**：收盤/非交易時段的下單由 broker 端拒絕並記錄 (跨午夜/多段 session 的精確排程未納入)。需自行於 Strategy Tester 納入 spread、commission、slippage 與多種市場狀態驗證。**反向平倉失敗防護與 Netting ownership 防護在回測中不易觸發 (tester 平倉幾乎必成、單帳戶單策略)，務必在實盤/模擬盤再次驗證。新增 SBR/RBS retest 後需重新以 MetaEditor 編譯確認。**

*   **`PrecisionSniperEA.mq5`**
    *   **功能**: PrecisionSniper 指標訊號自動交易 EA。
    *   **訊號來源**: 透過 `iCustom` 對接 `Indicators/PrecisionSniper.mq5`，讀取已收盤 K 棒 (`shift = 1`) 的 Buffer `3` Long signal 與 Buffer `4` Short signal，避免同一根 K 棒重複下單。
    *   **進場與過濾**: 支援 PrecisionSniper 的 Preset、HTF、signal grade 與 cooldown 參數；下單前使用最大 spread filter。反向訊號會先關閉相反方向持倉，且只有在平倉 retcode 確認成功、相反持倉已不存在後，才允許新方向進場。預設 `InpTradeOnFirstBar=false`，掛載後略過第一根既有訊號以避免 stale entry；spread 或 indicator buffer 暫時讀取失敗時不標記該 K 已處理，後續 tick 會重試。
    *   **倉位與止損**: 可使用固定手數，或依帳戶 equity、實際 stop distance 與 `OrderCalcProfit()` 估算的 1 lot 真實虧損計算風險手數；止損可選 swing structure 或 ATR multiplier。`PRESET_AUTO` 的 ATR 週期與指標端相同，會依 timeframe 解析。下單前強制驗證 `max(SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_TRADE_FREEZE_LEVEL) + spread`，SL 與伺服器端 TP3 距離不足時自動外推；保證金以 `OrderCalcMargin()` 預檢。
    *   **出場管理**: 以 TP1、TP2、TP3 的 R-multiple 管理部位，可在 TP1/TP2 分批平倉，並將 stop 依序移至 breakeven 與 TP1；TP3 為最終出場目標。分批階段由 `g_tp1Hit` / `g_tp2Hit` 旗標推進，且只有 `PositionModify` / `PositionClosePartial` / `PositionClose` retcode 確認成功後才更新階段，避免交易伺服器拒絕時 EA 誤以為已完成。短線研究控制預設關閉，可選 `InpUseMaxHoldingBars` 依當前週期限制最大持倉 K 棒、`InpUseNoOvernightExit` 在伺服器時間 cutoff 後禁止新倉並強制收倉、`InpUseFridayExit` 週五提前收倉。
    *   **交易時段控制**: 可選 `InpUseSessionFilter` 限制只在指定伺服器時間區間開新倉，支援跨午夜 session；此過濾只阻止新倉，不阻止既有持倉的 TP/SL/分批/強制平倉管理。反向訊號仍可先嘗試平掉反向倉，但在 session/cutoff 外不會反手開新倉。
    *   **回測與優化**: 提供 `OnTester()` 自訂適應度 (回報/相對回撤 × Profit Factor，要求 ≥30 筆交易以抑制過擬合)。優化模式 (`MQL_OPTIMIZATION`) 自動關閉 EMA/TPSL/Trail/Dashboard 等視覺物件以加速；`ShowSignals` 保持開啟以相容舊版 indicator，更新後的 indicator 已讓 buffer 與圖表顯示解耦。短線優化建議分輪測試 `InpMaxHoldingBars`、session hours、overnight/Friday cutoff，避免一次混合過多參數造成 overfitting。
    *   **使用限制**: Partial close 依賴 Hedging 帳戶及經紀商支援，且實際可平倉手數受 minimum volume 與 volume step 約束。指標內建 dashboard 的回測統計為指標自身模擬，與 EA 實際成交 (分批/移動止損時序不同) 不一致，不可當作 EA 的回測憑證。使用前必須確認 `iCustom` 參數順序、StopsLevel、spread、slippage、commission、broker server time、swap/rollover 時間，以及 EA 重啟後的持倉狀態恢復行為。
