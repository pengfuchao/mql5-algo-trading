# PrecisionSniperEA Strategy Research Log

最後更新：2026-07-02

> 本研究日誌遵循 [MT5 Strategy Research Workflow](MT5_Strategy_Research_Workflow.md)。流程定義、OOS 封存、統計穩健性（DSR / PBO / Monte Carlo）、時區與三倍 swap 規則請參考該文件。

## 1. 策略與測試範圍

- EA：`Strategies/PrecisionSniperEA.mq5`
- Indicator：`Indicators/PrecisionSniper.mq5`
- Symbol：EURUSD
- Tester：MetaQuotes-Demo，Build 5836
- Server time：待以 terminal / broker specification 確認；目前研究假設為夏令 GMT+3 / 冬令 GMT+2（session、overnight、Friday exit 皆以實際 broker server time 為準）
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

### 4.3 PrecisionSniper + SNR 通道距離過濾（淘汰）

構想：在 PrecisionSniper 原始訊號上疊加一層 SNR（Support/Resistance channel）距離過濾 —— 做多訊號若太靠近壓力區就擋掉、做空訊號若太靠近支撐區就擋掉；反向訊號仍先平掉反向倉，只有「開新倉」受過濾（B 模式 / `SNR_BLOCK_ONLY`）。

架構：`InpUseSNRFilter=true` 時，EA 以 `iCustom` 同時讀 `PrecisionSniper`（raw buy/sell buffer 3/4）與 `Support_Resistance_Channels`（NearestRes buffer 4 / NearestSup buffer 5），用 `距離 ≤ ATR × InpSNRBlockDistanceATR` 判定「太近」。預設 `InpUseSNRFilter=false`。

測試：`USDJPY / M15`，先跑長樣本比較，再以 2026.05 單月開 `InpSNRDebugLog` 做逐訊號診斷。

結果與排查過程：

| 階段 | 觀察 |
|---|---|
| 開/關 filter 長樣本比較 | 幾乎相同（withsnr 63.13 vs nosnr 60.02，6 年只有 2 筆 sell 被擋） |
| 掃 `InpSNRBlockDistanceATR` 0.3→5.0 | 全部相同 = baseline 217 筆，filter 形同無作用 |
| 加逐訊號 debug log | **每一個訊號都是 `最近壓力=0.000 最近支撐=0.000`** |
| 懷疑圖表 vs EA 參數不一致 | 對齊圖表參數（Pivot=10 / Width%=5 / MinStrength=1 / MaxNumSR=6 / Loopback=290 / Source=High/Low）後重跑 |
| 對齊後 | nearest **仍全為 0.000** |

判讀：

> ## ⛔ 本節原始判讀已於 2026-07-22 推翻，根因為 `input group` 參數錯位
>
> **原判讀（錯誤，保留供追溯）**：
>
> - ~~根因：`Support_Resistance_Channels` 的 NearestRes/NearestSup buffer（4/5）在 Strategy Tester 以 `iCustom` 載入時沒有被填出通道值（掛在圖表上能畫出通道，但回測環境 buffer 讀到 0）。~~
> - ~~「用指標 buffer 做距離過濾」這條路在回測層面確認行不通。~~
> - ~~若未來要重啟此構想，需改為 EA 內部自行計算 S/R 通道，不依賴該指標的輸出 buffer。~~
>
> **實際根因**：`Support_Resistance_Channels.mq5` 的第一個宣告是 `input group "Settings"`，而 **`input group` 會佔用一個 `iCustom` positional 參數位**。EA 以 positional 方式傳入 14 個參數，第一個值被 group 吃掉，其餘整體前移一位（機制與作廢 SR Channel 線 S1–S7 的 bug 相同，見 [Strategy_SR_Channel_Breakout](Strategy_SR_Channel_Breakout.md) §S10）。
>
> **驗證（2026-07-22，USDJPY M15 2026.05）**：指標端 `EFFECTIVE` 傾印實測
>
> ```
> PivotPeriod=4 Source=5 ChannelWidthPct=1 MinStrength=6 MaxNumSR=10 Loopback=100
> ChannelWidthMode=14 ATRLen=1 ATRMult=0.0100 UseVolumeFilter=true VolMaLen=1
> VolMult=0.1000 RetestTolerATR=20.0000 RetestExpiryBars=20
> ```
>
> 以「對齊圖表參數」那組輸入（`10 / 0 / 5 / 1 / 6 / 290 / 0 / 14 / 0.3 / false / 20 / 1.0 / 0.1 / 20`）代入偏移模型，**14 個欄位全部吻合**：`PivotPeriod` 收到空值夾成 4、`SourceMode` 收到 `ChannelWidthPct` 的 5、`MinStrength` 收到 `MaxNumSR` 的 6、`Loopback` 收到 `ChannelWidthMode` 的 0 夾成 100，餘類推。
>
> 錯位後的 `MinStrength=6 / ChannelWidthPct=1 / Loopback=100` 使通道數為 0，NearestRes/NearestSup 因此恆為 `0.000`。「掛圖表能畫、回測讀不到」的不對稱亦得解釋：**掛圖表時指標直接使用自身 input，不經過 `iCustom`，不會錯位。**
>
> 上表「對齊圖表參數後重跑，nearest 仍全為 0.000」那一步是關鍵誤導——對齊的是 EA 的 input 值，而錯位發生在傳遞層，對齊多少次都不會生效。
>
> **修正後的狀態**：
>
> - **此實驗從未成立**，「淘汰」結論撤回。SNR 距離過濾的有效性目前**未知**，非「已否定」。
> - 「用指標 buffer 做距離過濾行不通」是**假通則，已作廢**，不得作為未來設計依據。
> - 🔒 **`InpUseSNRFilter=true` 已於 2026-07-22 改為 fail closed**：EA 的 `iCustom` 呼叫仍為 positional，因此 `OnInit` 直接回傳 `INIT_PARAMETERS_INCORRECT` 並提示原因，避免有人開啟後得到一個「永遠放行卻毫無跡象」的過濾器（`AGENTS.md` 禁止事項 #6）。原始實作刻意保留未動。
>   **解除條件**：改用具名參數傳遞（如 SR Channel EA 的 global variable override），並以指標端 `SRchannel EFFECTIVE:` 逐項核對無誤後，移除 guard 即自動恢復。
> - 重啟優先序：應**先讓 PrecisionSniper 主線通過 [workflow Step 0.5 成本可行性預檢](MT5_Strategy_Research_Workflow.md)**（本研究日誌成文於 2026-07-02，早於 Step 0.5 的 07-20 導入，該關從未執行）。主線若過不了成本關卡，filter 是否有效並不重要。

- 現狀：`InpUseSNRFilter` 預設維持 `false`，既有 baseline 不受影響；`Indicators/PrecisionSniper_SNR.mq5`（早期 composite 指標）已不被 EA 使用，屬 orphaned。

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

### 5.1 H4 年度拆分與 200ms delay

Reports：

- `ReportTester-PS-H4-2023.html`
- `ReportTester-PS-H4-2024.html`
- `ReportTester-PS-H4-2025.html`
- `ReportTester-PS-H4-2026.html`
- `ReportTester-PS-H4-2020-2026-200ms.html`

| Period / Setting | Net Profit | PF | Expected Payoff | Sharpe | Trades | Win Rate | Max Equity DD |
|---|---:|---:|---:|---:|---:|---:|---:|
| H4 2023 | 117.74 | 3.31 | 5.89 | 1.72 | 20 | 35.00% | 30.72 / 0.31% |
| H4 2024 | -45.94 | 0.36 | -2.87 | -1.06 | 16 | 25.00% | 65.73 / 0.66% |
| H4 2025 | 31.90 | 1.72 | 1.88 | 0.82 | 17 | 29.41% | 28.56 / 0.29% |
| H4 2026 YTD | -8.21 | 0.70 | -0.82 | -0.13 | 10 | 20.00% | 28.36 / 0.28% |
| H4 2020.06.26–2026.06.26, 200ms delay | 99.38 | 1.24 | 0.91 | 0.48 | 109 | 30.28% | 79.12 / 0.78% |

判讀：

- H4 直接交易長樣本與 200ms delay 初步穩定，但年度拆分不穩，且平均持倉時間偏長。
- 2024 與 2026 YTD 為負，代表 H4 也不是穩定跨 regime edge。
- 使用者目標偏向 H1 / M15 短線，以降低 overnight / swap exposure，因此 H4 不應直接視為最終策略，只能作為 benchmark 或 trend context。

### 5.2 短週期 + HTF filter 測試

Reports：

- `PSM15H120202026.html`
- `PSH1H420202026.html`

| Setting | Net Profit | PF | Expected Payoff | Sharpe | Trades | Win Rate | Avg Holding |
|---|---:|---:|---:|---:|---:|---:|---:|
| H1 baseline | 50.46 | 1.06 | 0.12 | 0.33 | 423 | 30.73% | 27:05:00 |
| H1 + H4 filter | -6.70 | 0.99 | -0.02 | -0.06 | 316 | 31.33% | 29:20:31 |
| M15 + H1 filter | -163.11 | 0.87 | -0.12 | -1.15 | 1325 | 30.64% | 8:36:13 |

判讀：

- H1 + H4 filter 不採用：相較 H1 baseline，edge 消失。
- M15 + H1 filter 平均持倉時間較符合短線目標，但績效明確為負。
- HTF filter 本身沒有解決 H1/M15 短線獲利問題，下一步應測出場與時間風控，而不是繼續單純調 score / grade / HTF。

### 5.3 新增短線研究控制

為支援短線研究，`PrecisionSniperEA.mq5` v1.21 新增以下預設關閉 inputs：

- `InpUseMaxHoldingBars` / `InpMaxHoldingBars`：依當前週期限制最大持倉 K 棒，觸發後平掉本 EA 的 symbol + MagicNumber 持倉。
- `InpUseSessionFilter` / `InpSessionStartHour` / `InpSessionEndHour`：只允許在指定伺服器時間區間開新倉，支援跨午夜 session。
- `InpUseNoOvernightExit` / `InpNoNewTradeAfterHour` / `InpForceExitHour`：每日 cutoff 後不開新倉，並在 force-exit hour 後強制平倉。
- `InpUseFridayExit` / `InpFridayNoNewTradeAfterHour` / `InpFridayForceExitHour`：週五提前停止新倉與強制收倉，降低 weekend exposure。

設計原則：

- 預設關閉，因此既有 baseline 回測不應改變。
- 這些 controls 不改 PrecisionSniper signal buffer，也不改核心進場訊號邏輯。
- Session / cutoff 只阻止新倉；既有持倉的 TP/SL/分批/forced exit 仍會管理。
- Session / cutoff / Friday exit 的小時數均為 **broker server time**；目前研究假設為夏令 GMT+3、冬令 GMT+2，但仍需用 terminal / broker specification 確認。DST 切換週 London/NY overlap 會位移 1 小時，回測跨多年時需注意 session 統計被位移污染。換 broker 前必須重新確認其 GMT offset 與 DST 規則。
- 反向訊號仍可先平掉反向倉，但若當下不允許新倉，不會反手開新方向。

### 5.4 M15 短線候選：MaxHolding + Session

共用短線設定：

```text
Period=M15
HTF=H1
Preset=Default
GradeFilter=All
InpUseMaxHoldingBars=true
InpMaxHoldingBars=16
InpUseSessionFilter=true
InpUseNoOvernightExit=false
InpUseFridayExit=false
Delay=208ms
```

#### EURUSD 候選比較

| Candidate | Session | Total Net Profit | Total Trades | 年度特徵 |
|---|---:|---:|---:|---|
| A | 14–16 | 18.21 | 71 | 2023 明顯負，2026 強但樣本少 |
| B | 12–16 | 19.34 | 140 | 2023 僅小虧，年度分布較穩 |

EURUSD Candidate B 年度拆分：

| Year | Net Profit | PF | Expected Payoff | Sharpe | Trades | Max Equity DD | Avg Holding |
|---|---:|---:|---:|---:|---:|---:|---:|
| 2023 | -1.44 | 0.96 | -0.034 | -0.71 | 42 | 0.21% | 2:36:58 |
| 2024 | 11.73 | 1.44 | 0.279 | 7.34 | 42 | 0.12% | 2:38:40 |
| 2025 | 1.65 | 1.06 | 0.046 | 0.77 | 36 | 0.13% | 3:07:08 |
| 2026 YTD | 7.40 | 1.46 | 0.370 | 6.31 | 20 | 0.12% | 2:57:34 |

EURUSD spread stress：

| MaxSpread | Profit | PF | Expected Payoff | Sharpe | Trades |
|---:|---:|---:|---:|---:|---:|
| 20 | 11.69 | 1.057 | 0.048 | 0.91 | 243 |
| 25 | -8.44 | 0.959 | -0.036 | -0.69 | 233 |
| 30 | -6.36 | 0.969 | -0.028 | -0.53 | 229 |

判讀：

- EURUSD 短線版本可研究，但 edge 很薄。
- `MaxSpread=20` 是唯一正收益；不能放寬 spread filter。

#### 多商品 robustness

Candidate B 同設定套用至其他商品：

| Symbol | Net Profit | PF | Expected Payoff | Sharpe | Trades | Max Equity DD | Avg Holding | 判讀 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| USDJPY | 55.31 | 1.35 | 0.26 | 5.28 | 211 | 0.26% | 2:53:55 | 最佳候選 |
| EURUSD | 11.69 | 1.057 | 0.048 | 0.91 | 243 | 0.42% | 約 2–3 小時 | 可保留但 edge 薄 |
| XAUUSD | 23.04 | 1.02 | 0.10 | 0.67 | 234 | 2.12% | 2:31:27 | 接近 breakeven，DD 較高 |
| GBPUSD | -30.88 | 0.91 | -0.12 | -1.81 | 257 | 0.88% | 2:48:40 | 淘汰目前設定 |

#### USDJPY 最佳候選

目前最佳 USDJPY 設定：

```text
Symbol=USDJPY
Period=M15
HTF=H1
InpMaxSpread=15
InpUseMaxHoldingBars=true
InpMaxHoldingBars=16
InpUseSessionFilter=true
InpSessionStartHour=12
InpSessionEndHour=16
Delay tested: 208ms, 500ms, 1000ms
```

USDJPY `MaxSpread=15` 年度拆分：

| Year | Net Profit | PF | Expected Payoff | Sharpe | Trades | Max Equity DD | Avg Holding |
|---|---:|---:|---:|---:|---:|---:|---:|
| 2020 H2 | -3.38 | 0.71 | -0.169 | -4.16 | 20 | 0.06% | 3:12:34 |
| 2021 | 0.72 | 1.03 | 0.021 | 0.64 | 35 | 0.11% | 2:39:58 |
| 2022 | 6.66 | 1.24 | 0.196 | 2.99 | 34 | 0.15% | 3:18:28 |
| 2023 | 2.11 | 1.05 | 0.057 | 1.09 | 37 | 0.24% | 2:22:53 |
| 2024 | 1.14 | 1.03 | 0.031 | 0.56 | 37 | 0.20% | 2:18:29 |
| 2025 | 40.41 | 3.47 | 1.123 | 16.93 | 36 | 0.09% | 3:26:15 |
| 2026 YTD | 13.96 | 5.85 | 0.873 | 10.95 | 16 | 0.04% | 3:31:21 |

USDJPY `MaxSpread=15/20/25/30` stress：

| MaxSpread | Profit | PF | Expected Payoff | Sharpe | Equity DD | Trades |
|---:|---:|---:|---:|---:|---:|---:|
| 15 | 61.19 | 1.391 | 0.283 | 5.35 | 0.249% | 216 |
| 20 | 56.13 | 1.368 | 0.266 | 5.01 | 0.251% | 211 |
| 25 | 56.97 | 1.382 | 0.277 | 5.18 | 0.251% | 206 |
| 30 | 56.99 | 1.382 | 0.278 | 5.20 | 0.264% | 205 |

USDJPY delay stress：

| Delay | Net Profit | PF | Expected Payoff | Sharpe | Trades | Max Equity DD |
|---:|---:|---:|---:|---:|---:|---:|
| 208ms | 61.19 | 1.391 | 0.283 | 5.35 | 216 | 0.249% |
| 500ms | 62.56 | 1.400 | 0.290 | 5.43 | 216 | 0.24% |
| 1000ms | 58.96 | 1.377 | 0.273 | 5.13 | 216 | 0.25% |

判讀：

- USDJPY 是目前最強 short-term candidate。
- 2021–2026 全部年度為正，但 2021、2023、2024 接近 breakeven；2020 H2 為負。
- Edge 主要來自 2025–2026，仍可能存在 regime dependency。
- 以 `Profit=61.19 / Trades=216` 粗估，額外 commission + slippage 的 breakeven buffer 約 `0.283 USD/trade`。
- 500ms / 1000ms 延遲測試仍穩定正收益，execution delay sensitivity 初步通過。

## 6. 目前結論

### 保留研究

- `USDJPY / M15 / HTF=H1 / MaxSpread=15 / MaxHoldingBars=16 / Session=12–16` 作為目前最佳 short-term candidate。
- `EURUSD / M15 / HTF=H1 / MaxSpread=20 / MaxHoldingBars=16 / Session=12–16` 可保留為次要候選，但 edge 較薄。
- `EURUSD / H4 / Preset=Default / HTF=0 / GradeFilter=All` 僅作 benchmark，不符合短線低 swap 目標。

### 暫不採用

- H1 `GradeFilter=A&A+`
- H1 `Custom MinScore=6`
- H1 `Custom MinScore=7`
- D1 作為主策略設定：目前 trades 太少，只能作為觀察候選
- GBPUSD Candidate B 目前設定。
- XAUUSD Candidate B 暫不優先，因 PF 接近 1 且 drawdown 較高。
- PrecisionSniper + SNR 通道距離過濾（見 4.3）：**「淘汰」結論已於 2026-07-22 撤回**。filter 從未生效屬實，但根因是 `input group` 造成的 `iCustom` 參數錯位，非 tester buffer 問題。**此實驗從未成立，有效性未知**；重啟前須先修正參數傳遞，且應先讓主線通過 Step 0.5 成本預檢。

### 核心風險

- H1 長樣本 edge 很薄。
- H4 雖比 H1 好，但持倉時間過長，不符合降低 overnight / swap exposure 的主要目標。
- 2023 / 2024 regime 明顯拖累；H4 年度拆分亦顯示 2024 與 2026 YTD 偏弱。
- 目前多數測試使用 fixed 0.01 lot，金額結果不代表可放大後的真實風險承受度。
- 0.01 lot 無法完整驗證 partial close；partial close 功能測試應另用 0.03 lot 短期間 smoke test。
- USDJPY 最佳候選仍有 2020 H2 負收益，且 2021/2023/2024 只是接近 breakeven。
- USDJPY edge 的額外成本容忍度約 `0.283 USD/trade`，需確認 broker commission、spread 與實際 slippage。
- Session=12–16 等時間過濾以 broker server time 為準；目前 GMT+3 / GMT+2 僅為研究假設。不同 broker 的 GMT offset 或 DST 規則不同，換 broker 時 session 對應的實際市場時段會偏移，需重新驗證。
- 候選雖為短線，仍可能持倉跨 rollover；尚未檢查 USDJPY 多/空 swap 不對稱與 broker **週三三倍 swap 日**的持倉，需在成本評估中納入。

## 7. 下一步測試計畫

優先順序：

1. USDJPY 最佳候選進入 demo forward test：
   - 記錄實際 spread、commission、slippage、拒單、成交時間與持倉時間。
   - 確認 demo broker 的 server time / DST，將目前 GMT+3 / GMT+2 假設改為已驗證設定，並驗證 session 12–16 對應的實際市場時段。
   - 記錄是否持倉跨 **週三三倍 swap 日**，並統計實際 long / short swap 不對稱。
2. 若要正式驗證交易成本，建立 custom symbol 或使用實際 broker demo account 測 commission / execution。
3. 對 USDJPY 做更保守成本情境：
   - 手動用 `Adjusted Profit = Net Profit - Trades × extra_cost_per_trade` 評估 0.10 / 0.20 / 0.30 USD per trade。
4. Partial close 功能測試：
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

## 9. 附錄：EA 行為與介面文件（2026-07-04 自 `Strategies/README.md` 移入，行為文件以本節為準）

*   **功能**: PrecisionSniper 指標訊號自動交易 EA。
*   **訊號來源**: 透過 `iCustom` 對接 `Indicators/PrecisionSniper.mq5`，讀取已收盤 K 棒 (`shift = 1`) 的 Buffer `3` Long signal 與 Buffer `4` Short signal，避免同一根 K 棒重複下單。啟用 `InpUseSNRFilter=true` 時，EA 仍先讀 PrecisionSniper raw signal，再直接讀 `Support_Resistance_Channels.mq5` 的最近壓力/支撐位並在 EA 內套用 SNR filter；下游 execution、sizing、exit、session、partial close 與 trailing 邏輯不變。此設計避免 Strategy Tester 中 `PrecisionSniper_SNR -> PrecisionSniper -> built-in MA` 的 nested indicator handle 失敗。
*   **進場與過濾**: 支援 PrecisionSniper 的 Preset、HTF、signal grade 與 cooldown 參數；下單前使用最大 spread filter。可選 SNR 位置過濾會把 PrecisionSniper raw 動能訊號疊加 `Support_Resistance_Channels` 的最近壓力/支撐位：`SNR_BLOCK_ONLY` 只阻擋靠近反向 S/R 的訊號，`SNR_CONFIRMATION` 則要求訊號靠近順向 S/R 且不靠近反向 S/R。SNR filter 定位為**純進場位置過濾器**：raw 反向訊號仍會先關閉相反方向持倉 (風控不受過濾壓抑)，SNR filter 只決定「是否開被擋方向的新倉」。因此被 SNR 擋下時只做反向平倉、不反手開新倉。反向平倉在 retcode 確認成功、相反持倉已不存在後才會依 SNR filter 判斷是否開新方向。預設 `InpTradeOnFirstBar=false`，掛載後略過第一根既有訊號以避免 stale entry；spread 或 indicator buffer 暫時讀取失敗時不標記該 K 已處理，後續 tick 會重試。
*   **倉位與止損**: 可使用固定手數，或依帳戶 equity、實際 stop distance 與 `OrderCalcProfit()` 估算的 1 lot 真實虧損計算風險手數；止損可選 swing structure 或 ATR multiplier。`PRESET_AUTO` 的 ATR 週期與指標端相同，會依 timeframe 解析。下單前強制驗證 `max(SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_TRADE_FREEZE_LEVEL) + spread`，SL 與伺服器端 TP3 距離不足時自動外推；保證金以 `OrderCalcMargin()` 預檢。
*   **出場管理**: 以 TP1、TP2、TP3 的 R-multiple 管理部位，可在 TP1/TP2 分批平倉，並將 stop 依序移至 breakeven 與 TP1；TP3 為最終出場目標。分批階段由 `g_tp1Hit` / `g_tp2Hit` 旗標推進，且只有 `PositionModify` / `PositionClosePartial` / `PositionClose` retcode 確認成功後才更新階段，避免交易伺服器拒絕時 EA 誤以為已完成。短線研究控制預設關閉，可選 `InpUseMaxHoldingBars` 依當前週期限制最大持倉 K 棒、`InpUseNoOvernightExit` 在伺服器時間 cutoff 後禁止新倉並強制收倉、`InpUseFridayExit` 週五提前收倉。
*   **交易時段控制**: 可選 `InpUseSessionFilter` 限制只在指定伺服器時間區間開新倉，支援跨午夜 session；此過濾只阻止新倉，不阻止既有持倉的 TP/SL/分批/強制平倉管理。反向訊號仍可先嘗試平掉反向倉，但在 session/cutoff 外不會反手開新倉。
*   **回測與優化**: 提供 `OnTester()` 自訂適應度 (回報/相對回撤 × Profit Factor，要求 ≥30 筆交易以抑制過擬合)。優化模式 (`MQL_OPTIMIZATION`) 自動關閉 EMA/TPSL/Trail/Dashboard 等視覺物件以加速；`ShowSignals` 保持開啟以相容舊版 indicator，更新後的 indicator 已讓 buffer 與圖表顯示解耦。短線優化建議分輪測試 `InpMaxHoldingBars`、session hours、overnight/Friday cutoff，避免一次混合過多參數造成 overfitting。
*   **SNR inputs**: `InpSNRIndName` 預設為 `Support_Resistance_Channels`；若舊 `.set` 檔仍填 `PrecisionSniper_SNR`，EA 會在 log 提示並自動改用 `Support_Resistance_Channels`。SNR 端參數包含 `InpSNRPivotPeriod`、`InpSNRSourceMode`、`InpSNRChannelWidthPct`、`InpSNRMinStrength`、`InpSNRMaxNumSR`、`InpSNRLoopback`、`InpSNRChannelWidthMode`、`InpSNRATRLen`、`InpSNRATRMult`、`InpSNRUseVolumeFilter`、`InpSNRVolMaLen`、`InpSNRVolMult`、`InpSNRRetestTolerATR`、`InpSNRRetestExpiryBars`，以及 filter 端 `InpSNRMode`、`InpSNRBlockDistanceATR`、`InpSNRConfirmDistanceATR`。第一輪建議用 `InpSNRMode=SNR_BLOCK_ONLY`、`InpSNRChannelWidthPct=2`、`InpSNRMaxNumSR=3`、`InpSNRBlockDistanceATR=0.3`，先確認交易樣本沒有被壓到 0。
*   **使用限制**: Partial close 依賴 Hedging 帳戶及經紀商支援，且實際可平倉手數受 minimum volume 與 volume step 約束。指標內建 dashboard 的回測統計為指標自身模擬，與 EA 實際成交 (分批/移動止損時序不同) 不一致，不可當作 EA 的回測憑證。SNR nearest level 會隨 rolling loopback / pivot 更新而重算，EA 僅讀 `shift=1` filtered 訊號以避免 look-ahead，但 SNR filter 仍需 Strategy Tester、spread/slippage/commission、不同年份與參數敏感度驗證；`SNR_CONFIRMATION` 可能使交易樣本過少。使用前必須確認 `iCustom` 參數順序、StopsLevel、spread、slippage、commission、broker server time、swap/rollover 時間，以及 EA 重啟後的持倉狀態恢復行為。
