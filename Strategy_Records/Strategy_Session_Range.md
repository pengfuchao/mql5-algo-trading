# Strategy Session Range — 研究紀錄

相關發想：[London Breakout（亞洲盤區間突破）](../Strategy_Ideas/London_Breakout_Asian_Range.md)

最後更新：2026-07-05

狀態：`MODE_BREAKOUT` 已實作且編譯通過；第一輪 baseline 顯示 **GBPUSD / EURUSD 不通過**，**USDJPY M15 保留為二輪驗證候選**。目前暫停 GBPUSD 延伸研究，下一步切到 USDJPY Phase 2 測試；尚未進入 demo / live readiness。

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

| Symbol | Buy Profit / Trades / WR | Sell Profit / Trades / WR | 判讀 |
|---|---|---|---|
| GBPUSD | -2584.93 / 546 / 35.5% | -301.16 / 558 / 40.0% | 多單拖累嚴重；若未來只做診斷，可測 short-only，但 primary baseline 已否定 |
| EURUSD | -958.65 / 506 / 38.3% | -355.44 / 535 / 39.8% | 多空皆弱 |
| USDJPY | +628.05 / 242 / 41.3% | +2360.71 / 306 / 46.1% | edge 主要來自 sell side；可作二輪診斷 |

## 6. 決策

1. **GBPUSD London Breakout baseline：否定。**
   - 雖然單月 smoke 為正，但長樣本 PF 0.904、最大權益 DD 31.91%、多數年份虧損。
   - 不建議以 GBPUSD 直接進參數優化，否則容易變成 data mining。
2. **EURUSD 對照組：否定。**
   - 結果弱，且符合外部研究中 EURUSD London breakout 常見變體偏弱的判讀。
3. **USDJPY：保留研究，不晉級。**
   - 長樣本正期望，但 PF 只有 1.174；必須通過成本壓測、OOS / forward split、方向拆解後才能進一步討論。

## 7. 下一步

若繼續 `Strategy_Session_Range`：

1. USDJPY Phase 2 baseline rerun：`USDJPY / M15 / 2020.06.01–2026.06.30 / real ticks`，載入 `Strategy_Session_Range_USDJPY_Baseline.set`，確認結果可重現第一輪 PF 1.174 附近。
2. USDJPY OOS split：Development `2020.06.01–2023.12.31`、OOS `2024.01.01–2026.06.30`；不可再用 OOS 選參數。
3. USDJPY direction A/B：載入 `Strategy_Session_Range_USDJPY_BuyOnly.set` 與 `Strategy_Session_Range_USDJPY_SellOnly.set`；若 sell-only 才有 edge，需回到假說解釋為何 London breakout 對 USDJPY 空方更有效。
4. USDJPY cost stress：先用 report 計算 `break-even extra cost per trade = Net Profit / Trades`；目前第一輪 baseline 約 `2988.76 / 548 = 5.45` account-currency units/trade。若額外 spread、commission、slippage 的合理估計會吃掉大部分 expected payoff，則不晉級。`InpMaxSpreadPts` 測 10/15/20/25/30 只能視為流動性 gate sensitivity，不等同交易成本乘數。
5. GBPUSD 只保留時區與實作 sanity check；不作為優先研究線。

若要先實作其他策略：可以。建議優先選 **FX Time-of-Day** 或 **Weekend Gap Fade Phase 0 統計腳本**，因為它們比繼續調 GBPUSD London breakout 更符合「低參數、低 data-mining」原則；但 FX Time-of-Day 需要先確認 broker 成本，Weekend Gap 可先統計後決定是否寫 EA。

## 8. 已知限制

- Report 來自 MetaQuotes-Demo；broker server time、點差、commission、slippage 與實際帳戶可能不同。
- 目前記錄的是 baseline，不含獨立成本壓測、不含二家 broker tick data 驗證。
- v1 使用 server time 固定窗口，未處理 London / US DST 錯位週。
- `MODE_FADE` 尚未實作，不能用此 EA 代表亞洲盤均值回歸結果。
