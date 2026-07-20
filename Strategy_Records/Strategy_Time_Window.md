# Strategy Time Window — 研究紀錄

相關發想：[FX 時段效應](../Strategy_Ideas/FX_TimeOfDay_Effect.md)、[黃金日內季節性](../Strategy_Ideas/Gold_Intraday_Seasonality.md)

最後更新：2026-07-20

狀態：**兩條研究線皆結案。** `Strategies/Strategy_Time_Window.mq5` 為零指標的「定時進出」引擎，供純時間型假說共用。EURUSD FX 時段效應與 XAUUSD 黃金日內季節性均已完成正式回測並否定，**皆不進入 demo / live candidate**。引擎本身保留，供未來其他時間型研究復用。

## 1. 策略與版本

- EA：`Strategies/Strategy_Time_Window.mq5`（零指標；只有時間、點差 gate、災難 SL）
- 支援兩個獨立窗口（Window A / B），窗口 B 使用 `InpMagic+1`
- 設計 spec：[FX 時段效應檔 §10 Phase 1](../Strategy_Ideas/FX_TimeOfDay_Effect.md)

## 2. 共用測試環境

| 項目 | 設定 |
|---|---|
| Broker / build | MetaQuotes-Demo, Build 6034 |
| Deposit / 貨幣 | 10000 / USD |
| Leverage | 1:100 |
| Lots | 固定 `0.01` |
| Timeframe | H1 |

## 3. 研究線 A：EURUSD FX 時段效應 —— 否定

完整結果見 [FX_TimeOfDay_Effect.md §10](../Strategy_Ideas/FX_TimeOfDay_Effect.md)。摘要：

| 樣本 | Net | PF | Sharpe | Trades | 判定 |
|---|---:|---:|---:|---:|---|
| 2015.01–2026.06 | +309.39 | 1.044 | 0.457 | 5958 | 薄利，edge 不足 |
| 2020.01–2026.06 | -57.10 | 0.986 | -0.157 | 3368 | **不通過** |

結論：recent-regime edge 不存在，符合 alpha decay 疑慮。策略暫停，引擎保留。

## 4. 研究線 B：XAUUSD 黃金日內季節性 —— 否定

### 4.1 測試設定

Report：`XAUUSD Gold Intraday Seasonality MAIN.xlsx`

| 項目 | 值 |
|---|---|
| Preset | `Strategy_Time_Window_XAUUSD_Gold_MAIN.set` |
| 期間（請求） | H1, 2015.01.01–2026.06.30 |
| 期間（實際成交） | **2017.01.24–2026.06**（2015–2016 無 tick 資料；2017 僅 1 筆） |
| 質量歷史 | **65% 真實報價** |
| 窗口 | Window A BUY `03:00–10:00` server（≈ 00:00–07:00 UTC 亞洲時段） |
| `InpMaxSpreadPts` | 22.5（校準值） |
| 合約規格 | 驗證為 **100 oz/lot → `0.01 lot = 1 oz`**，故 `USD/trade` 數值等同 `USD/oz` |

> ⚠️ 偏差記錄：報告顯示 `InpCatastropheATRMult=2.0`，但 MAIN preset 為 `1.5`（preset 未完全生效）。影響評估：災難 SL 僅涉及極少數尾部交易，將最大單筆虧損 `-293.33` 收緊後 PF 由 1.028 變動至約 1.037，**不改變任何結論**，故未要求重跑。

### 4.2 核心績效

| Metric | Value |
|---|---:|
| Net Profit | **+232.65**（9.4 年，0.01 lot） |
| Gross Profit / Loss | 8475.56 / -8242.91 |
| Profit Factor | **1.028** |
| Expected Payoff | **0.110365 USD/trade（= USD/oz）** |
| Sharpe | **0.339** |
| Trades | 2108 |
| Win Rate | 49.00%（1033 / 1075） |
| 平均盈利 / 虧損 | 8.205 / -7.668 |
| 最大權益數虧損 | 699.12 (6.48%) |
| 平均持倉 | 6:58:47（吻合 7 小時窗口） |

### 4.3 G1 成本關卡 —— **不通過**

事前定義見 [Gold idea §10 G1](../Strategy_Ideas/Gold_Intraday_Seasonality.md)。回測已含 demo 點差，未含 commission / slippage / 真實點差差額。

`PF' = (GP − winners × cost) / (GL + losers × cost)`：

| 情境 | cost (USD/oz, RT) | PF' | 判定 |
|---|---:|---:|---|
| 樂觀 | 0.03 | 1.021 | 未達門檻 |
| **中性** | **0.29** | **0.956** | **不通過（門檻 1.10）** |
| 保守 | 0.47 | 0.913 | 不通過 |

**快速預檢同樣成立**：預期收益 `0.110 USD/oz` < 事前門檻 `0.29 USD/oz`，edge 僅為中性成本的約 38%。

依事前規則「中性 `PF' < 1.10` → 結案，不跑 CTRL」，**CTRL-1/2/3 對照組未執行且不需執行**。

### 4.4 逐年拆分 —— beta 假象確認

| Year | Net | Trades | Win Rate |
|---:|---:|---:|---:|
| 2017 | -4.29 | 1 | 0.0% |
| 2018 | -159.43 | 230 | 39.1% |
| 2019 | -107.17 | 252 | 45.6% |
| 2020 | -73.45 | 245 | 50.6% |
| 2021 | +177.12 | 258 | 51.2% |
| 2022 | -102.41 | 258 | 46.5% |
| 2023 | -10.22 | 257 | 49.8% |
| 2024 | **+190.29** | 224 | 58.0% |
| 2025 | **+421.22** | 257 | 51.4% |
| 2026 YTD | -99.01 | 126 | 49.2% |

**九年中六年為負**；全部淨利來自 2024–2025（央行購金潮高峰），2021 為唯一其他正年份。

這正是 idea §8 事前寫下的失效模式：「若效應只存在 2022 之後 → 那只是黃金大多頭的 beta，不是時段 alpha」。**逐年拆分獨立於成本關卡，亦得到否定結論**。

> 註：2019 / 2024 的 tick 資料原判斷有缺口，但本 run 逐年交易數穩定在 224–258，顯示 MAIN 單窗口配置下缺口影響有限。無論如何，缺口只會削弱「通過」的可信度，不影響本次的否定結論。

### 4.5 結論

**XAUUSD 黃金日內季節性結案，不進入 `Strategy_Live_Candidates/`。**

三個獨立面向皆否定：

1. **成本**：edge `0.110 USD/oz` < 中性成本 `0.29 USD/oz`，成本後 PF 0.956（淨負）。
2. **原始績效**：未扣額外成本前 PF 已僅 1.028、Sharpe 0.339，屬雜訊等級。
3. **穩定性**：9 年中 6 年為負，利潤集中於 2024–2025，符合 beta 假象定義。

經濟意義同樣不成立：9.4 年累計 +232.65 USD（0.01 lot），約 **25 USD/年**。

**不建議做參數優化**：在一個原始 PF 1.028、逐年多數為負的樣本上調參數，只會產生過擬合。空頭窗口（PM Fix 13:00–17:00 UTC）依 idea §10 規定「只有 MAIN 全關通過後」才測，**故亦不執行**。

## 5. 引擎狀態

`Strategy_Time_Window.mq5` 機械行為在兩條線的回測中均正常：進出場時刻與 inputs 一致、平均持倉吻合窗口長度、Friday window guard 生效、無隔夜週末持倉。**引擎保留供未來純時間型假說復用**，不隨研究線結案而廢棄。

## 6. 已知限制

- 兩條線的 report 均來自 MetaQuotes-Demo；broker server time、點差、commission 與實際帳戶不同。
- XAUUSD run 質量歷史僅 65% 真實報價，2015–2016 完全無資料。
- Demo 歷史點差呈現合成特徵（24 小時 median 幾乎持平、`avg < median`），因此成本情境採用實盤差額假設而非直接採信 demo 點差。校準細節見 [Gold idea §10](../Strategy_Ideas/Gold_Intraday_Seasonality.md)。
- v1 使用 server time 固定窗口，未處理歐美 DST 錯位週（每年 2–4 週偏移 1 小時）。

## 7. 方法論紀錄

本線與 `Strategy_Session_Range` 同日結案，兩者共同驗證了一個可複用的流程改進：

**把成本估算放在測試序列的第一步。** 兩條線都在成本關卡失敗，而該關卡是純桌面算術：

- `Session_Range`：edge ≈ 1 pip/筆 < commission ≈ 0.9 pip/筆 → 成本後 PF 0.98–1.02。
- `Time_Window` Gold：edge 0.110 USD/oz < 中性成本 0.29 USD/oz → 成本後 PF 0.956。

兩者都在成本關之前有「看起來還行」的指標（Session Range 的 OOS PF 甚至達 1.235）。**先算成本可在數分鐘內取得與多次 tester run 相同的結論。**
