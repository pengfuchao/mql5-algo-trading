# Indicators (自定義指標)

本資料夾主要存放 MetaTrader 5 (MT5) 的自定義指標 (`.mq5` 原始檔及 `.ex5` 執行檔)。這些指標可用於圖表分析，或作為 EA (Expert Advisor) 開發時的訊號來源。

## 檔案說明

以下為本資料夾內各個指標檔案的功能講解：

*   **`Currency_Correlation.mq5`**
    *   **功能**: 貨幣相關性指標。
    *   **說明**: 用於計算並顯示不同貨幣對之間的相關性係數，幫助交易者了解商品間的連動關係。

*   **`Donchian_Channel.mq5`**
    *   **功能**: 唐奇安通道指標 (Donchian Channel)。
    *   **說明**: 畫出過去 N 個週期的最高價與最低價區間，常被運用於突破策略（如海龜交易法則）。

*   **`ML_SuperTrend.mq5`**
    *   **功能**: 自適應 SuperTrend 訊號與市場狀態判斷指標。
    *   **核心邏輯**: 以 ATR 型 SuperTrend 為基礎，結合 RSI 極端區、成交量變化、Hurst Exponent、Entropy、ADX、波動率狀態與 tick pressure 產生 reversal 或 breakout 訊號。
    *   **自適應機制**: 透過背景模擬 probes、rolling performance、regime-volatility grid、decay traces 與 micro-batch learning，動態調整 ATR multiplier、ATR period、stop、target 與 breakout buffer。學習狀態只存在記憶體中，重新載入或完整重算時會重置。
    *   **風險控管**: 內建每個 session 的訊號數量、模擬虧損與連續虧損限制；這些限制只控制指標訊號，不等同於 EA 或帳戶層級的實際 risk manager。
    *   **顯示與通知**: 繪製多空 SuperTrend、Buy/Sell 箭頭、資訊 dashboard，並可選擇 popup 或 push notification。
    *   **EA Buffer Contract**:
        *   Buffer `0`: Bullish SuperTrend line。
        *   Buffer `1`: Bearish SuperTrend line。
        *   Buffer `2`: Buy signal price。
        *   Buffer `3`: Sell signal price。
        *   Buffer `4`: Signal confidence，範圍約為 `0–100`，供 EA 讀取但不繪圖。
    *   **使用限制**: Confidence 是根據內部規則與模擬記憶產生的 adaptive score，不是經統計校準的真實勝率。Dashboard 的實際訊號勝率採固定 5-bar outcome 評估，也不能直接視為完整策略績效。EA 建議讀取已收盤 K 棒 (`shift = 1`)，避免使用仍可能盤中變動的當前棒訊號。

*   **`PrecisionSniper.mq5`**
    *   **功能**: 多因子趨勢交叉、訊號評分與交易規劃指標。
    *   **核心邏輯**: 以 fast/slow EMA crossover 為觸發基礎，再使用 trend EMA、RSI momentum、MACD histogram、ADX/DI、相對成交量、價格位置及可選 Higher Timeframe (HTF) 趨勢進行加權評分與過濾。
    *   **Preset**: 提供 Auto、Scalping、Aggressive、Default、Conservative、Swing、Crypto、Gold 與 Custom 等參數組合，並可使用 A+、A、B、C 的 signal grade filter。
    *   **交易規劃**: 可依 swing structure 或 ATR multiplier 計算 stop loss，顯示 Entry、SL、TP1、TP2、TP3 與 trailing stop；同時提供 signal cooldown，避免短時間內重複訊號。
    *   **內建統計**: Dashboard 顯示趨勢、分數、波動狀態、交易狀態，以及勝率、平均 R、Profit Factor 和 TP/SL 統計；可選全部資料、日期區間或 rolling bars。
    *   **EA Buffer Contract**:
        *   Buffer `0`: Fast EMA。
        *   Buffer `1`: Slow EMA。
        *   Buffer `2`: Trend EMA。
        *   Buffer `3`: Long signal price。
        *   Buffer `4`: Short signal price。
    *   **EA 對接設計**: Buffer `0–4` 會持續填入資料，`ShowEMA` / `ShowSignals` 只控制圖表繪製，不再關閉 EA 可讀取的 buffer。HTF 趨勢過濾在訊號掃描時使用「當下已收盤」的 HTF K 棒，避免低週期歷史訊號讀到尚未完成的大週期 EMA。
    *   **使用限制**: 內建績效統計使用 OHLC bar path 與 R-multiple 進行模擬，不包含 spread、commission、slippage、swap 或真實成交限制；同一根 K 棒同時觸及 SL 與 TP 時採較保守的 SL 優先假設。Dashboard 只統計已結束的模擬交易，最後仍在進行中的交易顯示為 Active，不強制算入 closed-trade stats。因此它適合訊號研究與初步比較，不應取代 MT5 Strategy Tester 或 out-of-sample robustness test。

*   **`PrecisionSniper_SNR.mq5`**
    *   **功能**: PrecisionSniper + Support/Resistance Channels 的 composite signal filter 指標。
    *   **核心邏輯**: 先透過 `iCustom` 讀取 `PrecisionSniper.mq5` 的 raw Long/Short 訊號，再讀取 `Support_Resistance_Channels.mq5` 的最近壓力/支撐位，依 ATR-normalized distance 過濾進場位置不佳的訊號。此指標不改寫 PrecisionSniper 原始訊號邏輯，只在下游提供 filtered / blocked 訊號，方便圖表診斷 raw signal 是否被 SNR 擋掉。
    *   **Filter modes**:
        *   `SNR_BLOCK_ONLY`: Long 若靠近最近壓力則阻擋；Short 若靠近最近支撐則阻擋。這是第一版較寬鬆的位置品質過濾。
        *   `SNR_CONFIRMATION`: Long 必須靠近支撐且不能太靠近壓力；Short 必須靠近壓力且不能太靠近支撐。此模式較嚴格，可能大幅降低交易數。
    *   **Buffer Contract** (保持 `PrecisionSniper` drop-in 的 Buffer `3/4` 語意；`PrecisionSniperEA.mq5` 實際回測路徑已改為 EA 內直接讀 `Support_Resistance_Channels`，避免 Strategy Tester nested indicator handle 失敗):
        *   Buffer `0`: Raw Buy — PrecisionSniper 原始 Long signal price，否則 `0`。
        *   Buffer `1`: Raw Sell — PrecisionSniper 原始 Short signal price，否則 `0`。
        *   Buffer `2`: Nearest Resistance — `Support_Resistance_Channels` 的最近壓力位，否則 `0`。
        *   Buffer `3`: Filtered Buy — 通過 SNR filter 後的 Long signal price，否則 `0`。
        *   Buffer `4`: Filtered Sell — 通過 SNR filter 後的 Short signal price，否則 `0`。
        *   Buffer `5`: Nearest Support — `Support_Resistance_Channels` 的最近支撐位，否則 `0`。
        *   Buffer `6`: Blocked Buy — 被 SNR filter 阻擋的 raw Long signal price，否則 `0`。
        *   Buffer `7`: Blocked Sell — 被 SNR filter 阻擋的 raw Short signal price，否則 `0`。
    *   **`iCustom` 參數順序**: 先傳入 `PrecisionSniper` 的 `Preset, HTF, C_EmaFast, C_EmaSlow, C_EmaTrend, C_RSI, C_ATR, C_MinScore, C_SLMult, TP1_RR, TP2_RR, TP3_RR, SLMult, CooldownBars, UseTrail, StructureSL, SwingLB, GradeFilter, HideCGrade`；再傳入 SNR 的 `SNRPivotPeriod, SNRSourceMode, SNRChannelWidthPct, SNRMinStrength, SNRMaxNumSR, SNRLoopback, SNRChannelWidthMode, SNRATRLen, SNRATRMult, SNRUseVolumeFilter, SNRVolMaLen, SNRVolMult, SNRRetestTolerATR, SNRRetestExpiryBars`；最後傳入 `SNRMode, BlockDistanceATR, ConfirmDistanceATR, ShowRaw, ShowBlocked, ShowLevels`。
    *   **建議起始設定**: 為避免 S/R 通道過寬、層數過多而把 PrecisionSniper raw 動能訊號全數擋掉，第一輪建議使用 `SNRMode=SNR_BLOCK_ONLY`、`SNRChannelWidthPct=2`、`SNRMaxNumSR=3`、`BlockDistanceATR=0.3`，確認仍有足夠交易樣本後再測 `SNR_CONFIRMATION` 或更大的 ATR 距離。
    *   **使用限制**: 上游 S/R nearest level 會隨 rolling loopback 與新 pivot 重算，因此歷史 raw/filtered/blocked 顯示箭頭可能因重算而位移；EA 對接時仍應只讀已收盤 K 棒 (`shift = 1`) 的 Buffer `3/4`，但目前建議 EA 端直接套用 SNR filter。`SNR_CONFIRMATION` 可能造成樣本過少，`BlockDistanceATR` / `ConfirmDistanceATR` 對交易數與績效高度敏感，必須用 Strategy Tester 驗證，不能把指標目視效果視為回測結論。

*   **`Support_Resistance_Channels.mq5`**
    *   **功能**: 支撐/壓力「通道」指標 (SRchannel)，由 TradingView Pine Script v6 (© LonesomeTheBlue, MPL-2.0) 移植。
    *   **核心邏輯**: 以 Pivot Period 偵測左右對稱的樞紐高/低點，將彼此距離在「通道最大寬度」內的樞紐分群成通道；通道寬度預設維持近 300 棒振幅 × `ChannelWidthPct`%，也可切換為 closed-bar ATR × `ATRMult`。對每個通道統計 loopback 範圍內觸及的 K 棒數作為強度，挑出最強且互不重疊的數條通道並以矩形繪製。
    *   **顏色判定**: 通道整體在現價之上 → 壓力色；在現價之下 → 支撐色；現價落於通道內 → in-channel 色。
    *   **參數**: `PivotPeriod` (4–30)、`Source` (High/Low 或 Close/Open)、`ChannelWidthPct` (1–8)、`MinStrength`、`MaxNumSR` (1–10，沿用原版顯示語意)、`Loopback` (100–400)、`ChannelWidthMode` (`WIDTH_RANGE_PCT` 或 `WIDTH_ATR`)、`ATRLen`、`ATRMult`、`UseVolumeFilter`、`VolMaLen`、`VolMult`、`RetestTolerATR`、`RetestExpiryBars`、三色設定、`ShowPivot`、`ShowBroken`、`ShowBounce`、`ShowRetest`、`AlertsOn`，以及兩條可選 MA (SMA/EMA)。
    *   **突破偵測**: 現價脫離所有通道且收盤由壓力下方穿越其上 → Resistance Broken；由支撐上方跌破其下 → Support Broken；可繪箭頭並觸發 `Alert`。`UseVolumeFilter=true` 時，突破棒的 `tick_volume[1]` 必須大於前 `VolMaLen` 根已收盤歷史量均值 (`tick_volume[2..VolMaLen+1]`) × `VolMult`；歷史不足時不套用 volume gate。
    *   **反彈偵測**: 以已收盤棒的影線觸及/穿入通道、但收盤回到通道外側判定 rejection；壓力拒絕 → Resistance Bounce，支撐拒絕 → Support Bounce。此判定固定使用 `high[1]` / `low[1]`，與 pivot source mode 無關。
    *   **SBR/RBS 回測偵測**: 以 volume gate 之前的原始突破登記翻轉位；壓力被向上突破後凍結為 RBS 支撐，支撐被向下跌破後凍結為 SBR 壓力。後續已收盤棒在 `ATR × RetestTolerATR` 容差內回測並守住才輸出 RetestBuy/RetestSell；翻轉位收盤失守或超過 `RetestExpiryBars` 會失效。
    *   **EA Buffer Contract** (供 `iCustom` 讀取，建議 `shift = 1` 已收盤棒)：
        *   Buffer `0`: MA1 (繪圖)。
        *   Buffer `1`: MA2 (繪圖)。
        *   Buffer `2`: Resistance Broken — 突破當根收盤價，否則 `0`。
        *   Buffer `3`: Support Broken — 跌破當根收盤價，否則 `0`。
        *   Buffer `4`: 最近壓力位 (現價上方最近通道下緣)，否則 `0`。
        *   Buffer `5`: 最近支撐位 (現價下方最近通道上緣)，否則 `0`。
        *   Buffer `6`: Resistance Bounce — 壓力拒絕當根收盤價，否則 `0`。
        *   Buffer `7`: Support Bounce — 支撐拒絕當根收盤價，否則 `0`。
        *   Buffer `8`: Retest Buy — RBS 回測守住當根收盤價，否則 `0`。
        *   Buffer `9`: Retest Sell — SBR 回測守住當根收盤價，否則 `0`。
        *   `iCustom` 計算參數順序：`PivotPeriod, Source, ChannelWidthPct, MinStrength, MaxNumSR, Loopback, ChannelWidthMode, ATRLen, ATRMult, UseVolumeFilter, VolMaLen, VolMult, RetestTolerATR, RetestExpiryBars`（其餘顏色/Extras/MA 參數可省略用預設）。
    *   **實作說明 / 限制**:
        *   通道以 `OBJ_RECTANGLE` 物件繪製 (對應 Pine `box ... extend.both`)，向右延伸模擬全幅；MQL5 矩形不支援 Pine 的色彩透明度，改用可調實心色。
        *   **因果性**: S/R 的 channel width、strength 與 pivot 偵測皆以「已收盤棒 (`shift >= 1`)」為基準計算，**不使用形成中棒 bar0**，確保 EA 以 `shift=1` 讀到的突破訊號為因果安全 (無 look-ahead)。
        *   **與 Pine 非 signal-identical (有意設計差異，非等價移植)**：Pine 使用 `var` 持久化 pivot 陣列，且**只在新 pivot 被確認時**才重建 `suportresistance` 通道與重算 strength，並在**即時棒 (live bar)** 判定突破；本 MQL5 版改為**每根新收盤 K 棒從 loopback 視窗重建**通道，並在**已收盤棒 (`shift=1`)** 判定突破。因此即使沒有新 pivot，rolling 的 channel width / strength / selection 仍可能逐棒變動，導致 **TradingView 與 MT5 的 breakout 訊號不會完全一致**。此設計是為了 (a) 給 EA 因果安全的已收盤訊號、(b) 避免 live-bar repaint 進入 EA，刻意取捨；若需與 TV 完全相同需改回 live-bar/stateful 實作 (會引入 repaint，不建議用於 EA)。
        *   本質仍為 **repaint** 指標：通道會隨新樞紐與價格變動更新，歷史外觀不保證固定，EA 對接時只應信賴已收盤狀態。
        *   Pivot 蒐集視窗對齊 Pine 的 `bar_index - pivot_location > Loopback` 淘汰規則：有效 pivot 中心 shift 介於 `prd+1`（已收盤可確認）至 `loopback+prd`（淘汰邊界）；source 陣列長度取 `loopback+2*prd+2` 以免漏掉最舊約 `prd-1` 根仍有效的 pivot。
        *   Phase 2 retest 引入少量跨棒 stateful flip level（上限 16 個），但只在新 K 棒用 `shift=1` 更新；新登記的突破位不會在同一根突破棒立刻觸發 retest，以免退化成裸突破。
        *   突破、反彈與回測標記在最新收盤棒判定後以物件累積繪製，**不回填全部歷史**。Pine 排序段因 selection 已為降冪實際為 no-op，本版採乾淨交換取代原版 partial-swap quirk，顯示的通道集合不受影響。
        *   新增 SBR/RBS retest buffer 後需重新以 MetaEditor 編譯確認，並以預設 `SIG_BREAKOUT` 做 trade-sequence 回歸檢查。

*   **`Signal_3M.mq5`**
    *   **功能**: 3M 訊號指標。
    *   **說明**: 綜合特定條件產生交易訊號的指標，提供進出場點位的視覺化提示。

*   **`Template_iCustom_Call.mq5`**
    *   **功能**: 呼叫自定義指標的範本。
    *   **說明**: 展示如何在 MQL5 中使用 `iCustom` 或 Handle 的方式正確呼叫外部的自定義指標，並獲取其緩衝區 (Buffer) 數據，為 EA 開發者提供參考範例。
