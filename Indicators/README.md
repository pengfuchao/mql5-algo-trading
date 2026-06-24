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
    *   **使用限制**: 內建績效統計使用 OHLC bar path 與 R-multiple 進行模擬，不包含 spread、commission、slippage、swap 或真實成交限制；同一根 K 棒同時觸及 SL 與 TP 時採較保守的 SL 優先假設。因此它適合訊號研究與初步比較，不應取代 MT5 Strategy Tester 或 out-of-sample robustness test。

*   **`Signal_3M.mq5`**
    *   **功能**: 3M 訊號指標。
    *   **說明**: 綜合特定條件產生交易訊號的指標，提供進出場點位的視覺化提示。

*   **`Template_iCustom_Call.mq5`**
    *   **功能**: 呼叫自定義指標的範本。
    *   **說明**: 展示如何在 MQL5 中使用 `iCustom` 或 Handle 的方式正確呼叫外部的自定義指標，並獲取其緩衝區 (Buffer) 數據，為 EA 開發者提供參考範例。
