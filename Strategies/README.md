# Strategies (交易策略 / EA)

本資料夾存放各類 MetaTrader 5 (MT5) 自動化交易策略 (Expert Advisors, EA)。這些策略涵蓋從基礎範本到進階演算法（如網格、馬丁格爾、海龜交易等），主要使用現代化的 `CTrade` 訂單管理；部分策略明確依賴 Hedging 帳戶行為，使用前應確認帳戶模式與經紀商交易限制。

## 分層總表

| 分層 | 檔案 | 狀態 / 紀錄 |
|---|---|---|
| **研究管線** | `Strategy_SR_Channel_Breakout.mq5` | EURUSD H1 breakout 晉級 → [部署卡](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md)；研究紀錄見 [Strategy_Records](../Strategy_Records/Strategy_SR_Channel_Breakout.md) |
| **研究管線** | `PrecisionSniperEA.mq5` | USDJPY M15 候選，待 demo forward；研究紀錄見 [Strategy_Records](../Strategy_Records/PrecisionSniperEA.md) |
| **研究管線** | `Strategy_Session_Range.mq5` | **已結案**：GBPUSD/EURUSD 否定；USDJPY 通過 OOS 但成本關卡失敗；研究紀錄見 [Strategy_Records](../Strategy_Records/Strategy_Session_Range.md) |
| **研究原型** | `Strategy_Time_Window.mq5` | 定時進出引擎；**FX EURUSD 與 Gold XAUUSD 兩條研究線皆已結案否定**，EA 本身機械行為正常並保留作為純時間型研究引擎；研究紀錄見 [Strategy_Records](../Strategy_Records/Strategy_Time_Window.md) |
| **研究原型** | `Strategy_Weekend_Gap.mq5` | Weekend Gap Fade demo-forward prototype；M15 short sample 通過但長樣本不足，僅供研究蒐集執行證據，狀態見 [IDEA §10](../Strategy_Ideas/Weekend_Gap_Fade.md#10-實作規劃給-codex-的-spec) |
| **研究管線（待建紀錄）** | `Strategy_Turtle_Trading.mq5` | 實作完整但無回測紀錄，待補 baseline（建議 XAUUSD/USDJPY H1；出場 A/B 見 [TradingView harvest §2-B](../Strategy_Ideas/TradingView_External_Ideas_Harvest.md)）|
| **低優先待評估** | `EA_ML_SuperTrend.mq5` | confidence 未校準，先驗低 |
| **範本** | `Strategy_Template_MT5.mq5` | EA 開發標準範本 |
| **教學範例** | `Strategy_First_EA.mq5`、`Strategy_Second_EA.mq5`、`Strategy_Alligator_Force.mq5`、`Strategy_Modified_Alligator.mq5`、`Strategy_Indicator_Resonance_Long/Short.mq5` | 保留參考，不投入研究資源 |
| **不進研究管線** | `Strategy_MACD_Martingale.mq5`、`Strategy_Moving_Grid.mq5`、`Strategy_Optimized_Moving_Grid.mq5`、`Strategy_Hedging.mq5` | 馬丁/網格/對沖攤平屬負偏態資金管理型：回測曲線漂亮但尾部藏爆倉，結構性不可救（見 [開發框架 §1「偽機制」](../Strategy_Ideas/Quant_Strategy_Development_Framework.md)）。教學保留，**不優化、不部署** |

## 檔案說明

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

*   **`Strategy_Indicator_Resonance_Long.mq5` / `Strategy_Indicator_Resonance_Short.mq5`**
    *   **功能**: 指標共振策略（多頭/空頭專用）。
    *   **說明**: 當多個技術指標在特定週期上產生「共振」訊號時，觸發對應方向交易的策略系統。

*   **`Strategy_MACD_Martingale.mq5`**
    *   **功能**: MACD 馬丁格爾策略。
    *   **說明**: 結合 MACD 訊號與馬丁格爾加倉攤平。**不進研究管線**（理由見分層總表）。

*   **`Strategy_Moving_Grid.mq5` / `Strategy_Optimized_Moving_Grid.mq5`**
    *   **功能**: 動態網格策略（及其優化版）。
    *   **說明**: 依市場波動動態調整網格間距與掛單位置。**不進研究管線**（理由見分層總表）。

*   **`Strategy_Turtle_Trading.mq5`**
    *   **功能**: 經典海龜交易法則實作。
    *   **重點特性**: 55 棒唐奇安通道突破進場、ATR (N) 止損、每 0.5N 加倉（最多 `MaxUnits` 單位）、20 棒反向通道追蹤出場；正宗海龜 ATR 動態手數（`UseATRSizing`：`Unit = RiskPercent% × 淨值 ÷ (N × 每點價值)`，關閉時回退固定 `Lots`）；趨勢過濾（`UseTrendFilter`，EMA 100 定向，僅順勢掛突破單，轉向自動撤反向掛單）；掛單價與止損對齊 StopsLevel；ATR 取已收盤棒；內建 `OnTester` 自訂評分（恢復因子 × PF × √trades，`OptMinTrades` 防過擬合）。
    *   **狀態**: 工程完成度高但**尚無 `Strategy_Records/` 回測紀錄**，待補 baseline。

*   **`EA_ML_SuperTrend.mq5`**
    *   **功能**: 自適應機器學習 SuperTrend EA。
    *   **說明**: 對接 `Indicators/ML_SuperTrend.mq5` 的 Buffer `2`、`3`、`4` 取得 Buy、Sell 與 confidence 訊號，並使用已收盤 K 棒執行反轉交易。支援固定手數、ATR stop-distance 風險手數與 confidence 比例手數，搭配 ATR 初始 SL/TP 及 SuperTrend line trailing stop。
    *   **使用限制**: Confidence 是指標的 adaptive score，不是經校準的真實勝率；使用前必須確認 `iCustom` 路徑、參數順序、指標已編譯，並在 Strategy Tester 納入 spread、commission、slippage 與不同市場狀態。

*   **`Strategy_Weekend_Gap.mq5`**
    *   **功能**: Weekend Gap Fade 研究原型 EA。偵測 M15 週末跳空（週五最後一根 M15 與其後第一根 bar），等待第一根 M15 收盤與 M1 spread calm 條件後，反 gap 方向市價進場。
    *   **核心邏輯**: 5 pips / 0.3×D1 ATR 下限、1.5×D1 ATR breakaway 上限、週開盤後短窗口內進場、TP 到上週五收盤價或 80% 回補、SL 以 gap 倍數並受 D1 ATR cap 限制、週三 00:00 server time 強平。
    *   **現況**: Phase 0 只有 2022-06–2026-06 M15 short sample 通過；因長樣本不足與週一開盤回測品質風險，僅用於 demo forward 蒐集 spread、slippage、fill quality 與實際回補證據，**不得視為 live-ready**。完整研究狀態見 [Weekend_Gap_Fade.md](../Strategy_Ideas/Weekend_Gap_Fade.md)。

*   **`Strategy_Session_Range.mq5`**
    *   **功能**: 時段區間引擎 EA；v1 實作 London Breakout 的 `MODE_BREAKOUT`，保留 `MODE_FADE` 作為亞洲盤均值回歸的後續增量入口。
    *   **核心邏輯**: 以 server time 建立日內 range（預設 02:00–10:00，對應 EET/EEST broker 的 London 00:00–08:00），只用已收盤 M15 bar 累積 range high/low；range 結束後通過 `range height < K × D1 ATR` 品質 gate 才進入 ARMED，之後以收盤突破 range 上/下緣觸發市價做多/做空。
    *   **風控與出場**: 支援風險%手數（`InpFixedLots<=0` 時）或固定手數、點差上限、broker StopsLevel/FreezeLevel 檢查、range 對側 / ATR multiplier stop、RR take-profit、每日多空筆數上限、反向持倉未結束時不開新反向倉，以及 force close。
    *   **現況**: GBPUSD / EURUSD baseline 已否定；USDJPY M15 保留二輪成本壓測與 OOS 驗證，未晉級。
    *   **使用限制**: 所有時間 input 皆為 broker server time；v1 不做 DST-aware 換算，歐美 DST 錯位週可能偏移 1 小時。`MODE_FADE` 目前 fail-closed，不會交易。策略必須用 real ticks 驗證開盤點差、slippage、commission 與不同年份穩健性，不能直接由想法或單月 smoke test 推論 live readiness。完整結果見 [Strategy_Records/Strategy_Session_Range.md](../Strategy_Records/Strategy_Session_Range.md)。

*   **`Strategy_Time_Window.mq5`**
    *   **功能**: 共用定時進出 EA，第一版服務 FX Time-of-Day Effect，後續可由 Gold Intraday Seasonality 復用。沒有價格訊號與技術指標 filter，只依 broker server time 定時開倉、定時平倉。
    *   **核心邏輯**: 支援兩個獨立 window；預設 Window A 為 server 10:00–18:00 SELL，Window B 為 18:00–23:00 BUY；Window A 使用 `InpMagic`，Window B 使用 `InpMagic+1`。進場前只檢查 spread cap、late-entry grace、固定手數、交易權限、保證金、netting ownership；出場以 window close time 為主，週五 force close 防隔週末。Friday window 若預定 close time 等於或晚於 force-close time，會直接 skip，避免週五尾盤缺 tick 時跨週末持倉。`InpAllowFullDayWindow` 預設關閉；開啟後 open time = close time 代表 24h research window，供 Gold CTRL-3 beta control 使用。
    *   **風控與限制**: 使用 D1 ATR catastrophe SL，正常日不應觸發；所有時間 input 都是 server time，v1 接受 DST 錯位週 1 小時偏移。FX Phase 0 broker cost gate 已通過，但 EURUSD 2020–2026 baseline 轉負，FX idea 不進 live/demo candidate；Gold Intraday Seasonality MAIN/CTRL presets 已建立，待 XAUUSD H1 formal backtest。

*   **`Strategy_SR_Channel_Breakout.mq5`**
    *   **功能**: 支撐/壓力通道 EA（透過 `iCustom` 對接 `Indicators/Support_Resistance_Channels.mq5`），支援突破 / 反彈 / SBR-RBS 回測 / 混合四種訊號模式。
    *   **現況**: 通用多商品研究已結案；**EURUSD H1 裸突破晉級**，設置寫死於[部署卡](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md)（含 `.set`），等待 demo forward。
    *   **詳細文件**: 完整行為與介面文件（buffer contract、fail-closed sizing、Netting ownership 防護、OnTester 評分、使用限制）見 [Strategy_Records/Strategy_SR_Channel_Breakout.md](../Strategy_Records/Strategy_SR_Channel_Breakout.md) 附錄（§7）。

*   **`PrecisionSniperEA.mq5`**
    *   **功能**: PrecisionSniper 指標訊號自動交易 EA（`iCustom` 讀 Buffer `3`/`4`），可選 SNR 位置過濾（EA 端直讀 `Support_Resistance_Channels` 最近壓力/支撐）。
    *   **現況**: USDJPY M15 短線為最佳候選，待 demo forward；SNR filter 為研究中方向。
    *   **詳細文件**: 完整行為與介面文件（TP1/2/3 分批管理、session 控制、SNR inputs、使用限制）見 [Strategy_Records/PrecisionSniperEA.md](../Strategy_Records/PrecisionSniperEA.md) 附錄（§9）。
