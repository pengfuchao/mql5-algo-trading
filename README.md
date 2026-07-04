# MT5 Strategy Library

MQL5 程式庫 + 量化交易策略研究管線。除了指標、EA 與工具程式的原始碼之外，本 repo 以文件化的研究流程管理策略從發想到部署的完整生命週期：

```text
Strategy_Ideas（發想 + 實作 spec）→ Strategy_Records（回測證據與決策）→ Strategy_Live_Candidates（部署卡）
```

## 目錄結構 (Directory Structure)

*   **[Indicators](./Indicators/README.md)**: 自定義指標 (Custom Indicators) 原始碼與範例。
*   **[Strategies](./Strategies/README.md)**: 自動化交易策略 (Expert Advisors, EA)；README 開頭有分層總表（研究管線 / 教學範例 / 不進研究管線）。
*   **[Strategy_Ideas](./Strategy_Ideas/README.md)**: 策略發想、研究假說與給實作者的 spec（各檔 §10）；方法論總綱見[量化策略開發框架](./Strategy_Ideas/Quant_Strategy_Development_Framework.md)。
*   **[Strategy_Records](./Strategy_Records/README.md)**: 回測設定、實驗結果、研究決策與各 EA 行為文件；決策標準見[研究流程](./Strategy_Records/MT5_Strategy_Research_Workflow.md)。
*   **[Strategy_Live_Candidates](./Strategy_Live_Candidates/README.md)**: 回測全關通過、進入 demo/live 驗證的策略部署卡（寫死最優設置 + `.set` preset）。
*   **[Utilities](./Utilities/README.md)**: 實用腳本與模組範例（凍結參考庫；不可直接當 include 模組使用）。

## 使用說明

- 每一個子資料夾中都有一份 `README.md`，說明該資料夾內各程式的功能與狀態。
- AI coding agents 動工前請先讀 [AGENTS.md](./AGENTS.md)（工程規則、驗證要求、禁止事項）。
