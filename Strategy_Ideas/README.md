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

## 目前策略發想

| 策略想法 | 文件 | 狀態 |
|---|---|---|
| PrecisionSniper + SNR 位置過濾 | [PrecisionSniper_SNR_Filter.md](PrecisionSniper_SNR_Filter.md) | 優先研究方向 |
| SR Channel 指標升級：新增反彈訊號 | [SRChannel_Bounce_Signal_Upgrade.md](SRChannel_Bounce_Signal_Upgrade.md) | 已實作 / 待編譯與回測驗證 |
| SR Channel 指標升級：自適應 Pivot 取樣窗 | [SRChannel_Adaptive_Pivot_Window_Upgrade.md](SRChannel_Adaptive_Pivot_Window_Upgrade.md) | 發想 / 待實作（吸收自 SRv2） |
| 外部 SNR 指標想法彙整（6 支 TradingView） | [SNR_External_Ideas_Harvest.md](SNR_External_Ideas_Harvest.md) | Phase 1 A/C 已實作 / 其餘待評估 |
| SR Channel 指標升級（Phase 2）：SBR/RBS 回測進場 | [SRChannel_Retest_SBR_RBS_Upgrade.md](SRChannel_Retest_SBR_RBS_Upgrade.md) | 已實作 / 待編譯與回測驗證 |
