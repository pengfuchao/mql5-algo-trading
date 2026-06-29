# Strategy Live Candidates（實戰候選 / 部署卡）

本資料夾存放**回測基礎已全部通過、正在或即將進入實戰（demo / live）驗證**的策略。
每個策略一張「部署卡」，寫死驗證過的**最優設置**，作為實戰執行的單一真相來源。

## 研究 pipeline 分層

| 階段 | 資料夾 | 用途 |
|---|---|---|
| 1. 發想 | `Strategy_Ideas/` | 想法、設計草案、研究假說 |
| 2. 回測紀錄 | `Strategy_Records/` | 實際回測設定、結果、解讀、決策 |
| 3. **實戰候選** | **`Strategy_Live_Candidates/`** | **回測全關通過 → demo/live 驗證中的策略 + 部署卡** |

## 晉級門檻（進入本資料夾的條件）

一個策略要從 `Strategy_Records/` 晉級到此，至少需通過：

1. 全期 real ticks 正期望（PF、回撤可接受）。
2. 樣本外 / walk-forward（Forward 或滾動 OOS）未崩。
3. 穩定性（逐年 / 多窗多數為正，非單一 regime 撐起）。
4. **成本壓測**（含 commission，必要時含 swap/slippage）後 edge 維持。

未過以上者留在 `Strategy_Records/` 繼續研究或結案。

## 部署卡應包含

1. 狀態（demo forward / live）、幣種、週期、EA + 指標檔與版本
2. **完整 input 設置**（寫死、可直接套用）
3. 驗證摘要 + 連回 `Strategy_Records/` 的證據
4. 風控與部位規則
5. demo forward 檢查清單
6. **停用條件 (kill criteria)** —— 何時該下架/暫停

## 目前候選

| 策略 | 部署卡 | 幣種/週期 | 狀態 |
|---|---|---|---|
| SR Channel Breakout（EURUSD 專用）| [SR_Channel_Breakout_EURUSD.md](SR_Channel_Breakout_EURUSD.md) | EURUSD / H1 | demo forward 待啟動 |

## 注意

- 進入本資料夾**不等於 live ready**——demo forward 仍可能因實際滑點、swap、broker 差異或 live regime 而失效。
- 部署卡的設置一旦用於實戰，**任何更動都必須回到 `Strategy_Records/` 重新驗證**，不可在卡上直接調參數。
