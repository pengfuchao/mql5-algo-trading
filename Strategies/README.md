# Strategies (交易策略 / EA)

本資料夾存放各類 MetaTrader 5 (MT5) 自動化交易策略 (Expert Advisors, EA)。這些策略涵蓋了從基礎範本到進階演算法（如網格、馬丁格爾、海龜交易等），且均已適配 MT5 的對沖 (Hedging) 模式及現代化的訂單管理 (CTrade)。

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
    *   **說明**: 經典的海龜交易法則實作，包含 55 棒唐奇安通道突破進場、ATR (N) 止損、每 0.5N 加倉（最多 MaxUnits 單位）以及 20 棒反向唐奇安通道追蹤止損出場。出場機制純粹依 ATR 止損與通道追蹤，符合海龜順勢吃大波段的精神（已移除會提前了結趨勢的利潤鎖定機制）。**倉位管理採正宗海龜 ATR 動態手數（`UseATRSizing`）：以 `Unit = RiskPercent% × 淨值 ÷ (N × 每點價值)` 計算每單位手數，使單一單位 1N 不利波動約等於帳戶淨值的 `RiskPercent`%（預設 1%），手數隨波動率與淨值自動縮放，避免固定手數造成的爆倉風險；關閉時則回退為固定 `Lots`。** **內建趨勢過濾（`UseTrendFilter`）：以長週期均線（預設 EMA 100）判斷市場體制，僅在收盤價站上均線時掛多單突破、跌破均線時掛空單突破，過濾震盪盤的逆勢假突破以提升賺賠比；趨勢轉向時自動撤除不再符合方向的既有掛單。** 掛單價與止損皆對齊經紀商最小停損距離 (StopsLevel) 以避免 [Invalid stops] 拒單，並在持倉確立後即時取消反向突破掛單以防多空對沖；ATR 採用前一根已收盤 K 棒取樣，追蹤止損加入容差比較避免冗餘修改。

*   **`ML_SuperTrend.mq5`**
    *   **功能**: 自適應機器學習 SuperTrend 決策與信號源指標。
    *   **說明**: 結合動態市場體制偵測（Hurst Exponent、資訊熵、ADX）、二維上下文記憶網格（Regime Grid）、背景蒙地卡羅模擬探針（Faint Probes）與在線機器學習優化引擎（微批次 BatchFire 與動態 LearnProposals）的高自適應交易信號源。本版本已全面完成「實時動態勝率更新 desync 修復」、「Tick 級 delta 壓力量測優化」、「背景模擬風控防禦系統動態聯動」以及「底層 ArrayCopy 高效率平移優化」，確保回測與實盤表現高度一致且運行流暢。

*   **`EA_ML_SuperTrend.mq5`**
    *   **功能**: 自適應機器學習 SuperTrend 自動化交易智能交易系統 (EA)。
    *   **說明**: 專為對沖帳戶設計的自動化交易機器人，用於對接 `ML_SuperTrend` 信號源。支持三種高級資金管理（固定手數、基於 ATR 的淨值百分比風險手數、置信度比例手數），內置動態 ATR 止損止盈，以及基於指標軌跡線的移動止損 (Trailing Stop) 機械式出場，可在 MT5 策略測試器中生成完整的交易報告與資產淨值曲線。
