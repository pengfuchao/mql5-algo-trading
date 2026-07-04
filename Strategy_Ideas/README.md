# Strategy Ideas

本資料夾用來保存尚未正式進入回測紀錄階段的策略發想、交易邏輯設計、研究假說與待驗證清單。

## 與 Strategy_Records 的分工

| 資料夾 | 用途 |
|---|---|
| `Strategy_Ideas/` | 策略想法、設計草案、研究假說、預計測試方向 |
| `Strategy_Records/` | 已實際回測或優化後的設定、report、結果解讀與決策紀錄 |

## 建議文件內容

每個策略發想建議至少包含：

1. 核心想法
2. 策略假說
3. 使用的 indicator / EA
4. 進場條件
5. 過濾條件
6. 出場與風控
7. 第一輪測試計畫
8. 可能風險與失效條件
9. 進入 `Strategy_Records/` 的條件

## 方法論總綱

發想新策略前先讀：[Quant_Strategy_Development_Framework.md](Quant_Strategy_Development_Framework.md) —— 策略按機制/資訊源分類、訊號流水線解剖、指標與過濾器組合原則、想法評估計分卡、組合互補原則，以及 repo 現況在框架中的定位圖。**每個新想法都應該能在該框架裡定位自己（機制、資訊源、正交性、最便宜證偽路徑）。**

## 目前策略發想

| 策略想法 | 文件 | 狀態 |
|---|---|---|
| **SNR 未走完方向（待辦索引）** | [SNR_Open_Threads.md](SNR_Open_Threads.md) | 待辦索引（各項狀態以該檔為準）|
| PrecisionSniper + SNR 位置過濾 | [PrecisionSniper_SNR_Filter.md](PrecisionSniper_SNR_Filter.md) | 優先研究方向 |
| SR Channel 指標升級：新增反彈訊號 | [SRChannel_Bounce_Signal_Upgrade.md](SRChannel_Bounce_Signal_Upgrade.md) | 已實作 / 待編譯與回測驗證 |
| SR Channel 指標升級：自適應 Pivot 取樣窗 | [SRChannel_Adaptive_Pivot_Window_Upgrade.md](SRChannel_Adaptive_Pivot_Window_Upgrade.md) | 發想 / 待實作（吸收自 SRv2） |
| 外部 SNR 指標想法彙整（6 支 TradingView） | [SNR_External_Ideas_Harvest.md](SNR_External_Ideas_Harvest.md) | Phase 1 A/C 已實作 / 其餘待評估 |
| 外部 TradingView 高評價指標審視（7 支，2026-07 批次） | [TradingView_External_Ideas_Harvest.md](TradingView_External_Ideas_Harvest.md) | 審視完成：收 Squeeze（setup 閘門）+ Chandelier（出場 A/B）；Lorentzian/N-W/SMC 定案不做 |
| SR Channel 指標升級（Phase 2）：SBR/RBS 回測進場 | [SRChannel_Retest_SBR_RBS_Upgrade.md](SRChannel_Retest_SBR_RBS_Upgrade.md) | **已驗證／否定**：跨商品 retest ≤ breakout，策略結案（程式碼保留）|
| Vegas Tunnel + QQE MOD（趨勢濾清 + 動能觸發） | [Vegas_Tunnel_QQE_MOD.md](Vegas_Tunnel_QQE_MOD.md) | 發想 / 待實作（低期望探索，先驗成本低）|
| London Breakout（亞洲盤區間突破，GBPUSD M15） | [London_Breakout_Asian_Range.md](London_Breakout_Asian_Range.md) | **已附實作 spec（§10）**：`Strategy_Session_Range.mq5` BREAKOUT 模式 |
| FX 時段效應（本地時段貶值異象，EURUSD H1） | [FX_TimeOfDay_Effect.md](FX_TimeOfDay_Effect.md) | **已附實作 spec（§10）**：Phase 0 手算關 → `Strategy_Time_Window.mq5` |
| 黃金日內季節性（亞洲漲/歐美跌，XAUUSD H1） | [Gold_Intraday_Seasonality.md](Gold_Intraday_Seasonality.md) | **已附實作 spec（§10）**：復用 Time_Window 引擎 + 對照實驗設計 |
| 亞洲時段均值回歸（fade 假突破，M15） | [Asian_Session_Mean_Reversion.md](Asian_Session_Mean_Reversion.md) | **已附實作 spec（§10）**：Session_Range 引擎 FADE 模式增量（依賴 BREAKOUT 先完成）|
| 週末跳空回補（Weekend Gap Fade，M15 執行） | [Weekend_Gap_Fade.md](Weekend_Gap_Fade.md) | **已附實作 spec（§10）**：Phase 0 統計腳本先行（統計關不過就不寫 EA）|
