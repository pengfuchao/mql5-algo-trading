# Strategy Records

本資料夾用來保存每一套 MT5 strategy / EA 的研究紀錄、回測設定、結果解讀與後續決策。

## 使用規則

每一套策略建議建立一份獨立 Markdown 檔案，例如：

- `PrecisionSniperEA.md`
- `Strategy_SR_Channel_Breakout.md`

共用研究流程請參考：

- [MT5_Strategy_Research_Workflow.md](MT5_Strategy_Research_Workflow.md)

## 策略索引

採用上述流程的策略研究紀錄：

| 策略 | 研究紀錄 | 目前狀態 |
|---|---|---|
| PrecisionSniperEA | [PrecisionSniperEA.md](PrecisionSniperEA.md) | 研究中；USDJPY M15 短線為最佳候選，待 demo forward |

每份紀錄至少包含：

1. 策略與版本
2. 測試環境與共用設定
3. 每次回測的 report 檔名、期間、timeframe、主要 inputs
4. 核心績效指標：Net Profit、Profit Factor、Expected Payoff、Sharpe、Drawdown、Trades、Win Rate
5. 實驗結論：保留、淘汰、需複測或需修正
6. 下一步測試計畫

## 注意事項

- Strategy Tester report 通常存放在本機 `Downloads`，不直接提交 HTML / PNG 報告，除非明確需要保存 artifact。
- 回測結果不得視為 live trading readiness；必須另外檢查 spread、slippage、commission、swap、out-of-sample 與不同 market regimes。
- 若某個 input 在目前 preset 下不生效，必須明確記錄，避免重複跑無效測試。
