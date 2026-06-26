# PrecisionSniperEA Strategy Research Log

最後更新：2026-06-27

## 1. 策略與測試範圍

- EA：`Strategies/PrecisionSniperEA.mq5`
- Indicator：`Indicators/PrecisionSniper.mq5`
- Symbol：EURUSD
- Tester：MetaQuotes-Demo，Build 5836
- 初始入金：10000 USD
- Leverage：1:100
- Modeling：Every tick based on real ticks
- Fixed lot：`InpLots=0.01`
- Risk sizing：`InpUseRiskSize=false`
- Max spread：`InpMaxSpread=20`
- First-bar entry：`InpTradeOnFirstBar=false`
- Partial exit：enabled
- Trailing stop：enabled

## 2. 已確認的重要 input 行為

### 2.1 `C_MinScore` 只在 `Preset=Custom` 時生效

`Preset=Default` 時，indicator 會使用 preset 內建 score threshold：

- `Preset=3` / Default：`pScore=5`
- 這時即使 report 顯示 `C_MinScore=6` 或 `C_MinScore=7`，實際 signal 不會改變。

要測 Min Score，必須使用：

```text
Preset=8  // Custom
C_EmaFast=9
C_EmaSlow=21
C_EmaTrend=55
C_RSI=13
C_ATR=14
C_SLMult=1.5
C_MinScore=目標值
```

### 2.2 H4 / D1 report 目前是 chart timeframe，不是 HTF filter

目前已跑的：

- `ReportTester-PS-H4-2020-2026.html`：Period = H4，`HTF=0`
- `ReportTester-PS-D1-2020-2026.html`：Period = Daily，`HTF=0`

因此這兩份代表「直接用 H4 / D1 圖表週期交易」，不是「H1 chart + HTF=H4/D1 filter」。

若要測 HTF filter，必須保持：

```text
Period = H1
HTF = H4 或 D1
```

## 3. Baseline 與年度結果

### 3.1 M15 smoke test

Report：

- `C:\Users\pengf\Downloads\ReportTester-107044926.html`

設定：

```text
EURUSD / M15 / 2025.01.01 - 2025.12.31
Preset=Default
HTF=0
GradeFilter=All
InpLots=0.01
```

結果：

| Metric | Value |
|---|---:|
| Net Profit | -9.28 |
| Profit Factor | 0.97 |
| Expected Payoff | -0.03 |
| Sharpe | -0.25 |
| Trades | 302 |
| Win Rate | 31.13% |
| Max Equity DD | 93.11 / 0.93% |

判讀：

- EA 可正常交易，smoke test 通過。
- M15 edge 不足，交易 noise 偏高。

### 3.2 H1 2025 baseline

Report：

- `C:\Users\pengf\Downloads\ReportTester-107044927.html`

設定：

```text
EURUSD / H1 / 2025.01.01 - 2025.12.31
Preset=Default
HTF=0
GradeFilter=All
InpLots=0.01
```

結果：

| Metric | Value |
|---|---:|
| Net Profit | 44.60 |
| Profit Factor | 1.37 |
| Expected Payoff | 0.68 |
| Sharpe | 1.50 |
| Trades | 66 |
| Win Rate | 34.85% |
| Max Equity DD | 58.61 / 0.58% |

判讀：

- H1 明顯優於 M15。
- 但只有單一年份，不能直接視為穩定 edge。

### 3.3 H1 年度與長樣本

共用設定：

```text
EURUSD / H1
Preset=Default
HTF=0
C_MinScore=5
GradeFilter=All
InpLots=0.01
```

Reports：

- `ReportTester-PS-H1-2026.html`
- `ReportTester-PS-H1-2024.html`
- `ReportTester-PS-H1-2023.html`
- `ReportTester-PS-H1-2020-2026.html`

| Period | Net Profit | PF | Expected Payoff | Sharpe | Trades | Win Rate | Max Equity DD |
|---|---:|---:|---:|---:|---:|---:|---:|
| 2023 | -21.89 | 0.84 | -0.34 | -1.34 | 65 | 35.38% | 60.90 / 0.61% |
| 2024 | -41.58 | 0.66 | -0.59 | -2.35 | 70 | 25.71% | 55.25 / 0.55% |
| 2025 | 44.60 | 1.37 | 0.68 | 1.50 | 66 | 34.85% | 58.61 / 0.58% |
| 2026 YTD | 38.92 | 1.78 | 1.11 | 2.74 | 35 | 34.29% | 20.20 / 0.20% |
| 2020.06.26–2026.06.26 | 50.46 | 1.06 | 0.12 | 0.33 | 423 | 30.73% | 131.27 / 1.30% |

判讀：

- H1 在 2025、2026 表現較好。
- 2023、2024 失效，顯示 regime sensitivity。
- 2020–2026 長樣本只剩很薄的 positive edge：PF 1.06、Sharpe 0.33、Expected Payoff 0.12。
- 若納入更嚴格 commission / slippage / swap，長樣本 edge 可能被吃掉。

## 4. Filter 測試

### 4.1 GradeFilter = A&A+

Report：

- `ReportTester-PS-H1-2020-2026-A&A+.html`

設定：

```text
EURUSD / H1 / 2020.06.26 - 2026.06.26
Preset=Default
HTF=0
C_MinScore=5
GradeFilter=1  // A&A+
```

結果：

| Metric | Baseline All Signals | A&A+ |
|---|---:|---:|
| Net Profit | 50.46 | -57.45 |
| Profit Factor | 1.06 | 0.35 |
| Expected Payoff | 0.12 | -1.98 |
| Sharpe | 0.33 | -5.00 |
| Trades | 423 | 29 |
| Win Rate | 30.73% | 17.24% |
| Max Equity DD | 131.27 / 1.30% | 67.07 / 0.67% |

判讀：

- 淘汰。
- A&A+ 沒有提高 signal quality，只是大幅減少交易數並留下更差樣本。
- 不建議繼續測更嚴格的 A+ only，除非未來 score / grade 定義被重新設計。

### 4.2 Custom Min Score

Reports：

- `ReportTester-PS-H1-2020-2026-MIN6.html`
- `ReportTester-PS-H1-2020-2026-MIN7.html`

設定：

```text
EURUSD / H1 / 2020.06.26 - 2026.06.26
Preset=Custom
HTF=0
C_EmaFast=9
C_EmaSlow=21
C_EmaTrend=55
C_RSI=13
C_ATR=14
C_SLMult=1.5
GradeFilter=All
```

結果：

| Setting | Net Profit | PF | Expected Payoff | Sharpe | Trades | Win Rate | Max Equity DD |
|---|---:|---:|---:|---:|---:|---:|---:|
| Default / Min 5 | 50.46 | 1.06 | 0.12 | 0.33 | 423 | 30.73% | 131.27 / 1.30% |
| Custom / Min 6 | -3.80 | 0.99 | -0.02 | -0.06 | 155 | 28.39% | 125.32 / 1.24% |
| Custom / Min 7 | -41.54 | 0.42 | -1.81 | -4.33 | 23 | 21.74% | 58.74 / 0.59% |

判讀：

- `C_MinScore=6`：不採用，接近 breakeven 但略負。
- `C_MinScore=7`：淘汰，交易數過少且負期望。
- 目前 Min Score 不是有效優化方向。

## 5. Timeframe 測試

共用設定：

```text
EURUSD / 2020.06.26 - 2026.06.26
Preset=Default
HTF=0
C_MinScore=5
GradeFilter=All
InpLots=0.01
```

Reports：

- `ReportTester-PS-H1-2020-2026.html`
- `ReportTester-PS-H4-2020-2026.html`
- `ReportTester-PS-D1-2020-2026.html`

| Timeframe | Net Profit | PF | Expected Payoff | Sharpe | Trades | Win Rate | Max Equity DD | Avg Holding |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| H1 | 50.46 | 1.06 | 0.12 | 0.33 | 423 | 30.73% | 131.27 / 1.30% | 27:05:00 |
| H4 | 95.08 | 1.23 | 0.88 | 0.46 | 108 | 29.63% | 78.57 / 0.77% | 146:26:40 |
| D1 | 146.56 | 2.54 | 7.71 | 0.44 | 19 | 36.84% | 68.53 / 0.67% | 1004:06:20 |

判讀：

- H4 是目前最值得繼續研究的候選 baseline。
- H4 相比 H1：PF、Expected Payoff、Net Profit、Drawdown 都改善，且仍有 108 筆交易。
- D1 數字最好，但只有 19 筆交易，統計意義不足，且平均持倉約 41.8 天，需額外考慮 swap、隔週風險、重大事件風險與資金占用。

## 6. 目前結論

### 保留研究

- `EURUSD / H4 / Preset=Default / HTF=0 / GradeFilter=All`
- `EURUSD / H1 / Preset=Default / HTF=0 / GradeFilter=All` 作為 baseline comparison

### 暫不採用

- H1 `GradeFilter=A&A+`
- H1 `Custom MinScore=6`
- H1 `Custom MinScore=7`
- D1 作為主策略設定：目前 trades 太少，只能作為觀察候選

### 核心風險

- H1 長樣本 edge 很薄。
- 2023 / 2024 regime 明顯拖累。
- 目前多數測試使用 fixed 0.01 lot，金額結果不代表可放大後的真實風險承受度。
- 0.01 lot 無法完整驗證 partial close；partial close 功能測試應另用 0.03 lot 短期間 smoke test。
- 目前尚未完成 H4 年度拆分、H1+HTF filter、spread/delay stress test、多商品 robustness。

## 7. 下一步測試計畫

優先順序：

1. H4 年度拆分：
   - `EURUSD / H4 / 2023.01.01 - 2023.12.31`
   - `EURUSD / H4 / 2024.01.01 - 2024.12.31`
   - `EURUSD / H4 / 2025.01.01 - 2025.12.31`
   - `EURUSD / H4 / 2026.01.01 - 2026.06.26`
2. H1 + HTF filter：
   - `Period=H1, HTF=H4`
   - `Period=H1, HTF=D1`
3. Execution stress：
   - Delay = 200 ms
   - Max spread = 20 / 25 / 30
4. 多商品 robustness：
   - GBPUSD H4
   - USDJPY H4
   - XAUUSD H4，需獨立檢查 spread / stop level / tick value
5. Partial close 功能測試：
   - 用 `InpLots=0.03`
   - 短期間測試 TP1 / TP2 分批平倉是否符合預期

## 8. 決策標準

後續若要把某組設定升級為候選 strategy preset，至少需要：

- 長樣本 PF ≥ 1.15
- Expected Payoff > 0
- Sharpe 明顯高於目前 H1 baseline
- Trades 數量不能過少，除非策略明確定義為低頻 position trading
- 年度拆分不能只靠單一年份支撐
- Spread / delay 壓力測試後仍接近正期望
- 多商品或多市場 regime 下不應全面失效
