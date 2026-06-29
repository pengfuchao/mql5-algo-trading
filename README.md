# MT5-Coding-base

這是一個存放 MetaTrader 5 (MT5) 與 MQL5 相關語法、指標、策略及實用工具的代碼資料庫 (Repository)。
本專案主要是為了記錄與整理在開發 MT5 自動化交易程式 (Expert Advisors, EA) 時，所需要的各類模組化代碼與範例。

## 目錄結構 (Directory Structure)

本專案將代碼與研究文件分類為以下主要資料夾：

*   **[Indicators](./Indicators/README.md)**: 存放自定義指標 (Custom Indicators) 相關的原始碼與範例。
*   **[Strategies](./Strategies/README.md)**: 存放各類自動化交易策略 (Expert Advisors, EA) 的完整邏輯與架構。
*   **[Strategy_Ideas](./Strategy_Ideas/README.md)**: 存放尚未進入正式回測紀錄階段的策略發想、交易邏輯設計與研究假說。
*   **[Strategy_Records](./Strategy_Records/README.md)**: 存放策略回測設定、實驗結果、優化紀錄與研究決策。
*   **[Strategy_Live_Candidates](./Strategy_Live_Candidates/README.md)**: 存放回測全關通過、進入 demo/live 驗證的策略部署卡（寫死最優設置）。
*   **[Utilities](./Utilities/README.md)**: 存放各種實用的腳本與模組，例如：圖表物件繪製、訂單管理、資金計算、時間控制等。

## 使用說明

每一個子資料夾中都有一份 `README.md`，詳細說明了該資料夾內每一支程式 (`.mq5` 檔案) 的具體功能與用途。開發者可依據需求進入各別目錄查看詳細資訊。
