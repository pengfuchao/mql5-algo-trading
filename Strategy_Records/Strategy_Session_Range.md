# Strategy Session Range — 研究紀錄

相關發想：[London Breakout（亞洲盤區間突破）](../Strategy_Ideas/London_Breakout_Asian_Range.md)

最後更新：2026-07-20

狀態：**結案（2026-07-20）**。`MODE_BREAKOUT` 已實作且編譯通過；GBPUSD / EURUSD baseline 否定；USDJPY 通過 OOS（OOS PF 1.235 優於 Dev 1.134，無樣本外衰減）但**在成本關卡決定性失敗**——毛 edge 約 1 pip/筆，低於 commission 約 0.9 pip/筆的地板，成本後 PF 降至 0.98–1.02。詳見第 6.1 節。不進入 demo / live readiness。

> ⚠️ 第 5 節的多空拆解欄位原本標反，已於 2026-07-20 更正：**USDJPY 的 edge 來自 buy side 而非 sell side**。

## 1. 策略與版本

- EA：`Strategies/Strategy_Session_Range.mq5`
- 模式：`InpMode=MODE_BREAKOUT`
- 策略假說：亞洲盤建立低波動區間，倫敦開盤後若 M15 收盤突破區間高/低，短期 order-flow 可能沿突破方向延續。
- 實作狀態：
  - `MODE_BREAKOUT`：已完成。
  - `MODE_FADE`：保留 enum 與入口，但目前 fail-closed，不交易；等亞洲盤均值回歸 spec 進入實作時再增量開啟。

## 2. 共用測試環境與 inputs

來源 report：

- `C:\Users\pengf\Downloads\202401-202402.xlsx`
- `C:\Users\pengf\Downloads\GBPUSD2020-26.xlsx`
- `C:\Users\pengf\Downloads\EURUSD2020-2026.xlsx`
- `C:\Users\pengf\Downloads\USDJPY2020-26.xlsx`

共用設定：

| 項目 | 設定 |
|---|---|
| Broker / build | MetaQuotes-Demo, Build 5973 |
| History quality | 100% real ticks |
| Deposit | 10000 |
| Account currency | EUR |
| Leverage | 1:100 |
| Timeframe | M15 |
| Date range（長樣本） | 2020.06.01–2026.06.30 |
| Risk | `InpRiskPercent=0.5`, `InpFixedLots=0` |

核心 inputs：

| Input | Value |
|---|---:|
| `InpMode` | 0 (`MODE_BREAKOUT`) |
| `InpRangeStartHour/Min` | 2 / 0 |
| `InpRangeEndHour/Min` | 10 / 0 |
| `InpTradeEndHour/Min` | 13 / 0 |
| `InpForceCloseHour/Min` | 19 / 0 |
| `InpMaxSpreadPts` | 20.0 |
| `InpMaxLongPerDay` / `InpMaxShortPerDay` | 1 / 1 |
| `InpATRPeriod` | 14 |
| `InpRangeQualityK` | 0.5 |
| `InpSLMode` | `RANGE_OPPOSITE` |
| `InpSLATRMult` | 1.5 |
| `InpTPRR` | 1.5 |

時間假設：所有 session input 都是 broker server time；目前 v1 不做 DST-aware London conversion。

### 時區 sanity note（GBPUSD 10:15–10:25 進場）

若 MT5 report 顯示的是 **broker server time**，`10:15` 附近開倉不代表時區算錯。EA 預設用 server `02:00–10:00` 建立 range，`10:00–10:15` 的 M15 bar 收盤後才做 closed-bar breakout 判斷，因此第一筆可成交 tick 落在 `10:15` 或其後數分鐘屬於合理行為。

後續若重查 GBPUSD，只做實作診斷，不做參數優化：

- 正常：server `10:15` 左右，或 `10:16–10:25` 因 tester tick 稀疏才成交。
- 需懷疑：大量交易在 server `12:15` 左右才進，或 range 明顯包含 London open 後波動。
- 判定方式：抽 3–5 筆，對照 M15 chart 的 `02:00–10:00` range、`10:00–10:15` 收盤突破、以及成交 tick。

## 3. 第一輪 baseline 結果

### S1 — GBPUSD M15 smoke test（2024.01.01–2024.02.01）

Report：`202401-202402.xlsx`

| Metric | Value |
|---|---:|
| Net Profit | +87.09 |
| Profit Factor | 1.195 |
| Expected Payoff | 5.443 |
| Sharpe | 2.220 |
| Trades | 16 |
| Max Equity DD | 3.29% |
| Win Rate | 43.75% |

判讀：機械 smoke test 通過基本要求：EA 有開倉、出場、TP/SL，且 M15 收盤後進場時間落在預期 London breakout 視窗內。但樣本只有 16 筆，不能作為策略有效證據。

### S2 — 三商品長樣本 baseline（2020.06–2026.06）

| Symbol | Net Profit | PF | Expected Payoff | Sharpe | Trades | Max Equity DD | Win Rate | 結論 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| GBPUSD | -2886.09 | 0.904 | -2.614 | -3.086 | 1104 | 31.91% | 37.77% | 不通過 |
| EURUSD | -1314.09 | 0.955 | -1.262 | -1.364 | 1041 | 21.12% | 39.10% | 不通過 |
| USDJPY | +2988.76 | 1.174 | +5.454 | 4.179 | 548 | 7.22% | 43.98% | 保留二輪驗證 |

判讀：

- GBPUSD 是原始想法的 primary symbol，但長樣本 PF < 1、淨利為負、回撤高，且 1104 筆交易代表樣本足夠；此 baseline 否定，不應直接優化。
- EURUSD 作為對照組偏弱，符合外部證據方向，但仍無可交易 edge。
- USDJPY 是唯一正期望結果；PF 1.174 未達部署門檻，但 drawdown 較低、年度拆分較穩，值得進二輪成本與 OOS 驗證。

## 4. 年度拆分

### GBPUSD

| Year | Profit | Trades | Win Rate |
|---:|---:|---:|---:|
| 2020 | -520.97 | 118 | 36.4% |
| 2021 | -518.96 | 194 | 38.1% |
| 2022 | +325.36 | 175 | 42.3% |
| 2023 | -419.52 | 194 | 38.1% |
| 2024 | -400.49 | 183 | 37.7% |
| 2025 | -1449.85 | 151 | 30.5% |
| 2026 YTD | +98.34 | 89 | 41.6% |

結論：不是單一年份拖累；多數年份弱，2025 嚴重失效。GBPUSD baseline 應先記為否定。

### EURUSD

| Year | Profit | Trades | Win Rate |
|---:|---:|---:|---:|
| 2020 | -97.01 | 112 | 39.3% |
| 2021 | -1180.05 | 189 | 34.9% |
| 2022 | +514.55 | 165 | 42.4% |
| 2023 | -356.70 | 188 | 38.8% |
| 2024 | -292.80 | 185 | 39.5% |
| 2025 | +25.59 | 135 | 40.0% |
| 2026 YTD | +72.33 | 67 | 40.3% |

結論：EURUSD 對照偏弱，未見可投入研究資源的 edge。

### USDJPY

| Year | Profit | Trades | Win Rate |
|---:|---:|---:|---:|
| 2020 | -542.57 | 66 | 33.3% |
| 2021 | +731.32 | 105 | 45.7% |
| 2022 | +878.79 | 96 | 46.9% |
| 2023 | +357.66 | 88 | 43.2% |
| 2024 | +22.92 | 88 | 40.9% |
| 2025 | +1212.00 | 62 | 51.6% |
| 2026 YTD | +328.64 | 43 | 46.5% |

結論：2021–2026 多數年份為正，2020 為主要失效年；仍需成本壓測與 OOS，不能視為 live candidate。

## 5. 方向拆解

> ⚠️ **2026-07-20 更正**：本表原本的 Buy / Sell 兩欄**標反了**。MT5 報告的欄位順序是「賣出交易」在前、「買入交易」在後，紀錄時誤當成 Buy 在前，三個商品全部受影響。下表為更正後版本，並已由 `buyonly.xlsx` / `sellonly.xlsx` 兩份獨立單向 run 交叉驗證。

| Symbol | Buy Profit / Trades / WR | Sell Profit / Trades / WR | 判讀 |
|---|---|---|---|
| GBPUSD | -301.16 / 558 / 40.0% | -2584.93 / 546 / 35.5% | **空單**拖累嚴重（原紀錄誤植為多單）；primary baseline 已否定 |
| EURUSD | -355.44 / 535 / 39.8% | -958.65 / 506 / 38.3% | 多空皆弱 |
| USDJPY | **+2360.71 / 306 / 46.1%** | +628.05 / 242 / 41.3% | **edge 主要來自 buy side**（原紀錄誤植為 sell side）|

單向獨立驗證（全期 2020.06–2026.06，`InpSLMode=1`）：

| Run | Report | Net Profit | PF | Trades | Expected Payoff |
|---|---|---:|---:|---:|---:|
| Buy only | `buyonly.xlsx` | +2428.81 | **1.251** | 306 | 7.937 |
| Sell only | `sellonly.xlsx` | +422.09 | 1.061 | 242 | 1.744 |

兩種算法一致：**多方是 edge 來源，空方接近雜訊**。原 §6 中「edge 主要來自 sell side」的判讀作廢。

## 6. 決策

1. **GBPUSD London Breakout baseline：否定。**
   - 雖然單月 smoke 為正，但長樣本 PF 0.904、最大權益 DD 31.91%、多數年份虧損。
   - 不建議以 GBPUSD 直接進參數優化，否則容易變成 data mining。
2. **EURUSD 對照組：否定。**
   - 結果弱，且符合外部研究中 EURUSD London breakout 常見變體偏弱的判讀。
3. **USDJPY：保留研究，不晉級。**
   - 長樣本正期望，但 PF 只有 1.174；必須通過成本壓測、OOS / forward split、方向拆解後才能進一步討論。
   - **2026-07-20 更新：Phase 2 已完成，結論為結案。** 見第 6.1 節。

## 6.1 Phase 2 結果與結案（2026-07-20）

### S9–S11：OOS / 方向拆解（已於 2026-07-05 執行，2026-07-20 補入紀錄）

| Run | Report | 期間 | Net | PF | Trades | Expected Payoff | Sharpe |
|---|---|---|---:|---:|---:|---:|---:|
| Baseline | `USDJPY2020-26.xlsx` | 2020.06–2026.06 | +2988.76 | 1.174 | 548 | 5.454 | 4.179 |
| Development | `Development.xlsx` | 2020.06–2023.12 | +1431.74 | 1.134 | 355 | 4.033 | 3.462 |
| OOS | `OOS.xlsx` | 2024.01–2026.06 | +1330.52 | **1.235** | 193 | 6.894 | 5.308 |

全部為 `100% 真實報價`。**OOS 表現優於 Development，無樣本外衰減** —— 這條線的訊號本身是真的，不是曲線配適。

### S8：成本關卡 —— **不通過，結案**

實際平均成交手數 `0.78 lot`（自 `USDJPY2020-26.xlsx` 委託明細計算，非估算）。帳戶貨幣 EUR，`InpRiskPercent=0.5`，SL 模式 `RANGE_OPPOSITE` 搭配 `InpRangeQualityK=0.5` 造成平均 SL 僅約 11 pips，因而手數偏大。

換算為 pips：

```text
每筆 edge   = 5.4539 EUR / 5.38 EUR-per-pip ≈ 1.01 pips
Commission  = $7/lot 來回 ÷ $7.69 pip value ≈ 0.91 pips
```

**關鍵性質：commission 換算成 pips 之後與部位大小無關**（commission 與 pip value 都隨 lot 等比放大）。因此這不是調整 `InpRiskPercent` 或 SL 距離能解決的問題，**是結構性的**。

成本後 PF（`GP=20133.82`、`GL=17145.06`、winners 241 / losers 307）：

| 情境 | PF' |
|---|---:|
| 回測原始（real ticks，已含 demo spread）| 1.174 |
| + commission `$7/lot` 來回 | **1.016** |
| + commission + slippage `0.25 pip` | **0.977** |

事前門檻為 `PF' < 1.15 → 結案`。實測 `PF' ≈ 0.98–1.02`，**決定性不通過**。

### 結案決定

**`Strategy_Session_Range` USDJPY 線結案，不晉級 `Strategy_Live_Candidates/`。**

理由不是訊號無效（OOS 反而更好），而是**毛 edge 約 1 pip/筆，小於零售交易成本**。此結論對 `MODE_BREAKOUT` 的當前參數族成立。

若未來要重啟，唯一有意義的方向是**提高每筆 edge 的絕對值**，而非優化勝率或 PF：

- 放寬 TP（目前 `InpTPRR=1.5`）或改用趨勢跟隨出場，讓單筆獲利遠大於 1 pip 級別。
- 放寬 `InpRangeQualityK`，不再只挑極窄區間 —— 窄區間造成 SL 極近、手數極大，是成本佔比過高的根因。
- 換到成本佔比較低的環境（更高週期、或 commission-free 且點差不劣於 demo 的帳戶）。

**不建議**在現有參數族上繼續優化 PF；1 pip 的 edge 無論如何調權重都跨不過 ~0.9 pip 的 commission 地板。

## 7. USDJPY Phase 2 執行 checklist（已執行完畢，結論見第 6.1 節）

> **狀態：已完成，本線結案。** S9–S11 已於 2026-07-05 執行，S8 於 2026-07-20 完成並否決本線。以下保留原始 checklist 設計作為方法論參考，供其他策略線複用。

最後整理：2026-07-20。以下為可直接執行的順序，**順序本身是設計的一部分，不要跳步**。

### 順序上的兩個修正（vs 原始條列）

1. **成本估算提前到第一步。** 原本列為第 4 步，但它是純桌面算術、不需跑 tester，且最有可能直接否定這條線。依框架「最便宜證偽路徑」原則提前。
2. **方向 A/B 必須在 Development 期間內做，不能在全樣本做。** 原始條列把 OOS split（第 2 步）與 direction A/B（第 3 步）並列，但方向選擇**本質上是一次參數選擇**；若在全樣本挑出 sell-only 再看 OOS，OOS 已被污染。正確做法是所有選擇都在 Dev 完成、凍結後 OOS 只跑一次。

### S8 — 成本關卡（桌面算術，不跑 tester）

- [ ] 從既有 report `USDJPY2020-26.xlsx` 讀出**實際平均成交手數**（不要用估算值）。
- [ ] 計算每筆實際成本：`spread_pips × pip_value × lots + commission × lots + slippage_pips × pip_value × lots`。
- [ ] 與 break-even `Net Profit / Trades = 2988.76 / 548 = 5.45` EUR/trade 比較。
- [ ] 用勝率 43.98%（winners 241 / losers 307）重算成本後 PF：
      `PF' = (GP − winners × cost) / (GL + losers × cost)`，其中 `GP = 20166`、`GL = 17177`。

**事前講定的門檻**：`PF' < 1.15` → **這條線結案**，不再跑 S9–S12。

> **實測結果（2026-07-20）**：實際平均手數為 `0.78 lot`（先前估算 0.20 lot 過低約 4 倍）。成本後 `PF' ≈ 0.98–1.02`，**不通過，本線結案**。完整計算見第 6.1 節。
>
> 方法論註記：本步驟以桌面算術在 10 分鐘內得到與四次 tester run 相同的結論，驗證了「成本關卡提前」的價值。**建議其他策略線也把成本估算放在第一步。**

### S9 — Baseline 重現（S8 通過才做）

- [ ] `USDJPY / M15 / 2020.06.01–2026.06.30 / real ticks`，載入 `Strategy_Session_Range_USDJPY_Baseline.set`。
- [ ] 確認 tester 報告的**實際起始日與 model quality**（M15 歷史深度需另外確認；Gold 線已出現過 broker 歷史不足而 tester 安靜縮短區間的情況）。
- [ ] 結果需重現 PF 1.174 附近。**不重現則先查環境差異，不要接著往下跑。**

### S10 — 方向 A/B（**只在 Development 期間**）

- [ ] 期間固定 `2020.06.01–2023.12.31`。
- [ ] 分別載入 `..._BuyOnly.set` 與 `..._SellOnly.set`，與同期 baseline 比較。
- [ ] ⚠️ 更正後的第 5 節顯示**多空皆為正**（buy +2360.71 / 306 筆、sell +628.05 / 242 筆），edge 集中在 **buy** 側。既然 sell 側不是負的，限制為單向的理由很弱，**預設應保留雙向**；只有在 Dev 期間某一側明確為負、且能提出機制解釋時才可改單向。
- [ ] 若真要改單向，必須先在本檔寫下機制假說（為何 London breakout 對 USDJPY 某一方向更有效），再進 S11。**先有解釋，後有選擇。**

### S11 — OOS 確認（凍結後只跑一次）

- [ ] 期間 `2024.01.01–2026.06.30`，配置為 S10 凍結的結果。
- [ ] **只跑一次，不得依 OOS 結果回頭改任何設定。** 若要改，整個 Phase 2 需重新設計並重跑。

### S12 — 最終成本壓測

- [ ] 對 S11 的 OOS 結果套用 S8 的實際成本，重算 PF 與 expected payoff。
- [ ] `InpMaxSpreadPts` 測 10/15/20/25/30 **只能視為流動性 gate sensitivity，不等同交易成本乘數**，不可拿來當成本壓測。

### 晉級門檻

通過 S8–S12 後，仍需符合 [Strategy_Live_Candidates](../Strategy_Live_Candidates/README.md) 的四道門檻才可晉級。**S9 的全樣本 PF 1.174 本身未達門檻**，因此本線的實際判定取決於 S12 的成本後數字。

### 其他

- GBPUSD 只保留時區與實作 sanity check；不作為優先研究線。

若要先實作其他策略：可以。建議優先選 **FX Time-of-Day** 或 **Weekend Gap Fade Phase 0 統計腳本**，因為它們比繼續調 GBPUSD London breakout 更符合「低參數、低 data-mining」原則；但 FX Time-of-Day 需要先確認 broker 成本，Weekend Gap 可先統計後決定是否寫 EA。

## 8. 已知限制

- Report 來自 MetaQuotes-Demo；broker server time、點差、commission、slippage 與實際帳戶可能不同。
- 目前記錄的是 baseline，不含獨立成本壓測、不含二家 broker tick data 驗證。
- v1 使用 server time 固定窗口，未處理 London / US DST 錯位週。
- `MODE_FADE` 尚未實作，不能用此 EA 代表亞洲盤均值回歸結果。
