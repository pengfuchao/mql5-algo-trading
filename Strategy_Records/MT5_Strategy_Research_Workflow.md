# MT5 Strategy Research Workflow

最後更新：2026-06-27

本文件定義一套標準化 MT5 外匯策略研究流程，用來讓策略從「想法與程式撰寫」進入「可重現回測、參數優化、stress test、demo forward test」時更有效率。重點不是找出單次最漂亮的 report，而是判斷策略是否有可解釋、可重現、能承受交易成本的 edge。

## 1. 核心原則

### 1.1 研究目標

每一套策略都要先回答：

1. 策略假說是什麼？
2. 交易週期是短線、波段，還是趨勢追蹤？
3. edge 來自哪裡：trend、breakout、mean reversion、volatility regime、session effect，或多指標 confirmation？
4. 主要風險是什麼：spread、slippage、swap、低交易次數、過度參數化、特定年份失效？

若策略假說無法清楚說明，即使 backtest 盈利，也先視為 data mining candidate，不視為可投入真實交易的策略。

### 1.2 優化原則

- 先驗證策略邏輯，再優化參數。
- 先測單一代表性商品，再擴展到多商品。
- 先做粗篩，再做細部優化。
- 先看穩定性，再看最大報酬。
- 每次只改少量 inputs，避免不知道哪個變數造成結果變化。
- 不把 in-sample 最佳組合直接視為 production setting。
- **OOS 必須在任何 screening 或優化「之前」就切走並封存**，封存區間不得用於選 symbol、timeframe 或參數，否則 OOS 已被污染、失去驗證意義。
- **記錄整個研究過程的總試驗次數**（symbol × timeframe × 參數組合）。試驗越多，最佳結果為運氣的機率越高，Sharpe 的可信門檻也要跟著提高（見 Step 9 的 DSR / PBO）。
- 所有 report 必須記錄 timeframe、symbol、date range、delay、spread、commission、slippage、核心 inputs 與結論。

### 1.3 時區與環境基準

所有 session filter、no overnight entry、Friday exit、rollover 判斷都以 **broker server time** 為準（不是台灣時間、也不是 GMT），因此每份紀錄都要標明 broker 時區與當下處於夏令或冬令。

常見外匯 broker 可能採 EET/EEST server time（冬令 GMT+2 / 夏令 GMT+3），但不同 broker 可能不同，必須逐一確認。不要只因為 report 來自 MT5 就假設一定是 GMT+2 / GMT+3。

| 期間 | Broker server time | 與台灣（GMT+8）差距 |
|---|---|---|
| 夏令假設 | GMT+3 | 台灣比 server 快 5 小時 |
| 冬令假設 | GMT+2 | 台灣比 server 快 6 小時 |

注意事項：

- DST 切換的那兩週，London / New York overlap 對應的 server hour 會位移 1 小時；session filter 若寫死 server hour，overlap 會跑掉。回測涵蓋多年時，這個位移會週期性污染 session 統計。
- **Swap 三倍日**：多數 FX 在 broker 的**週三**收三倍 swap（部分商品在週五），不是只有週五要注意。短線降 swap 策略必須同時測週三三倍日。
- 紀錄 session 時建議同時寫 server hour 與換算後的台灣時間，避免日後回溯混淆。

## 2. 建議總流程

```text
策略假說
  -> 切分並封存 OOS 區間
  -> 指標 / EA 程式碼檢查
  -> baseline smoke test
  -> 單一 symbol development-period baseline
  -> 年度切片檢查
  -> timeframe / HTF matrix
  -> symbol universe 篩選
  -> 參數粗優化
  -> out-of-sample / walk-forward
  -> spread / commission / slippage / delay / swap stress test
  -> 統計穩健性與過擬合檢驗 (Monte Carlo / DSR / PBO)
  -> position sizing 與風控測試
  -> demo forward test
  -> production candidate or reject
```

## 3. Step 0：策略假說與交易設計

在寫 EA 或正式回測前，先建立研究假說。

建議記錄：

| 項目 | 說明 |
|---|---|
| Strategy Name | EA / indicator 名稱 |
| Hypothesis | 為什麼這個訊號應該有 edge |
| Market Regime | 適合 trend、range、high volatility 或 low volatility |
| Holding Period | 預期持倉時間，例如 M15 intraday、H1 swing、H4 multi-day |
| Entry Logic | 進場訊號來源 |
| Exit Logic | TP、SL、trailing、time exit、reverse signal |
| Risk Model | fixed lot、equity risk %、ATR stop、structure stop |
| Major Cost Risk | spread、commission、slippage、swap、rollover |
| Failure Mode | 最可能失效的市場狀況 |

短線策略尤其要先定義「最大可接受持倉時間」。若目標是降低 overnight swap，不能只看總報酬，還要看平均持倉時間、最長持倉時間、隔夜交易比例。

## 4. Step 1：程式碼與交易安全檢查

在任何大型回測前，先檢查 EA 是否符合基本交易安全。

### 4.1 Indicator 檢查

- buffer index 是否固定且文件化。
- EA 使用的 signal buffer 是否只讀 completed bar，例如 `shift = 1`。
- 是否有 repaint 或 intrabar 更新問題。
- `iCustom` input 順序是否與 indicator 一致。
- preset 與 custom inputs 的實際生效條件是否清楚。

### 4.2 EA 檢查

- 是否用 `MagicNumber` 與 symbol 過濾所有 positions / orders。
- 是否檢查 minimum lot、maximum lot、volume step。
- 是否檢查 stop level、tick size、tick value。
- 是否處理 trade execution failure，並記錄 `ResultRetcode()` / `ResultRetcodeDescription()`。
- 是否避免同一根 bar 重複開倉，除非策略明確需要。
- 是否只在允許交易時間開新倉，但仍允許出場與風控執行。
- 若使用 partial close，需確認最小手數與剩餘手數合法。

### 4.3 Smoke test

先跑短期間，例如 1 至 3 個月：

- 目標不是看績效，而是確認沒有 runtime error。
- 檢查是否真的有開倉、平倉、TP、SL。
- 檢查 log 是否有大量 failed order、invalid stops、invalid volume。
- 檢查 report 的交易方向與策略邏輯是否一致。

## 5. Step 2：建立 baseline

baseline 是後續所有優化的參考點。

建議 baseline 設定：

| 項目 | 建議 |
|---|---|
| Modeling | Every tick based on real ticks |
| Deposit | 固定，例如 10000 USD |
| Lot | 先用 fixed lot，例如 0.01 |
| Risk sizing | 初期關閉，避免績效被 compounding 影響 |
| Optimization | 關閉 |
| Delay | 先用接近實際 ping，例如 200ms 左右 |
| Timeframe | 依策略假說，短線先 M15 或 H1 |
| Date Range | 使用 development period，例如 2020-2023；已封存 OOS 不得用於 baseline 判斷 |

資料品質要求：

- Strategy Tester 的 modeling quality / history quality 要達可接受門檻（real tick 模式下盡量接近 100%），並記錄 tick data 來源與 broker。
- baseline / screening 階段可先用 1 家 broker 快速篩選；進入候選參數 validation 後，**同一策略至少用 2 家 broker 的 tick data 各跑一次**。這是最便宜也最有效的 data-artifact 與過擬合偵測：若兩家結果差異巨大，通常是資料假象或對單一 broker 報價過度敏感，不是真 edge。
- 留意週末跳空、重大新聞 spike 與 tick 缺漏對 real-tick 回測的影響。

baseline 階段不要急著調參數。先回答：

1. 策略是否有足夠交易次數？
2. profit 是否只集中在少數交易？
3. drawdown 是否可接受？
4. 年度表現是否極端不穩？
5. 平均持倉時間是否符合策略目標？

## 6. Step 3：年度切片檢查

長期間總績效容易掩蓋問題，因此必須做 yearly split。

建議順序：

1. 先跑 development period 全期間，例如 `2020-01-01` 至 `2023-12-31`；不得包含已封存 OOS。
2. 再逐年跑 development period 內的年度切片，例如 2020、2021、2022、2023。
3. 記錄每年 Profit、Profit Factor、Expected Payoff、Sharpe、Drawdown、Trades。
4. 標記每一年為 strong、acceptable、weak、failed。

判讀原則：

- 若總績效主要來自單一年份，代表穩定性不足。
- 若多數年份接近 breakeven，策略可能只有很薄的 edge。
- 若交易次數過少，不能過度解讀 Sharpe 或 Profit Factor。
- 若某些年份虧損但 drawdown 很小，可以保留觀察，但不能直接放大手數。

## 7. Step 4：Timeframe 與 HTF filter 測試

timeframe 測試要分清楚「圖表週期」與「HTF filter」。

例如：

| 測試類型 | Period | HTF input | 解讀 |
|---|---:|---:|---|
| M15 原始策略 | M15 | current/off | 用 M15 交易 |
| M15 + H1 filter | M15 | H1 | M15 entry 搭配 H1 trend filter |
| H1 原始策略 | H1 | current/off | 用 H1 交易 |
| H1 + H4 filter | H1 | H4 | H1 entry 搭配 H4 trend filter |
| H4 benchmark | H4 | current/off | 直接用 H4 交易，不是 H1+H4 |

若目標是短線且降低 overnight swap，建議順序：

1. M15 baseline
2. M15 + H1 filter
3. H1 baseline
4. H1 + H4 filter
5. H4 只作為 benchmark，不優先作為 production candidate

H4 若表現很好，要拆解原因：是訊號更穩定，還是只是持倉更久吃到大趨勢。若主要獲利來自 multi-day holding，必須額外測 swap 與隔夜風險。

## 8. Step 5：Symbol universe 篩選

不要一開始就對所有 symbol 做大範圍 optimization。建議先用固定 baseline inputs 做 symbol screening。

### 8.1 建議測試順序

第一輪先測 major FX：

1. EURUSD
2. USDJPY
3. GBPUSD
4. AUDUSD
5. USDCAD
6. USDCHF
7. NZDUSD

第二輪再測 cross pairs：

- EURJPY
- GBPJPY
- EURGBP
- AUDJPY
- CADJPY

第三輪才測非典型商品：

- XAUUSD
- index CFD
- oil / energy CFD

XAUUSD 與 index CFD 的 tick value、spread、trading session、commission 與 volatility 結構和 major FX 差異很大，不應直接用 FX 結論外推。

### 8.2 Symbol screening 指標

每個 symbol 至少記錄：

| Metric | 用途 |
|---|---|
| Net Profit | 方向性參考，不單獨作決策 |
| Profit Factor | 粗略衡量勝負比 |
| Expected Payoff | 每筆交易期望值，與成本壓力直接相關 |
| Max Drawdown | 風險承受度 |
| Trades | 樣本數 |
| Avg Holding Time | 是否符合短線目標 |
| Long / Short split | 是否只靠單邊行情 |
| Annual consistency | 是否跨 regime 有效 |

若 `Expected Payoff` 很小，即使 profit 為正，也必須優先進入 cost stress test。

## 9. Step 6：參數優化順序

參數優化要先分層，不要一次把所有 inputs 全開。

### 9.1 第一層：策略方向性參數

這類參數會改變訊號本質，例如：

- EMA fast / slow / trend period
- RSI period
- ATR period
- minimum score / grade filter
- HTF filter

這一層只做粗範圍搜尋，用來確認策略在哪種 regime 比較有效。

### 9.2 第二層：出場與風控參數

例如：

- stop loss method
- ATR stop multiplier
- TP1 / TP2 / TP3 Risk:Reward
- trailing stop
- max holding bars
- partial close ratio

這一層通常比進場參數更容易造成過擬合。若某組 TP/SL 只在單一年份有效，通常不採用。

### 9.3 第三層：交易條件過濾

例如：

- session filter
- no overnight entry
- Friday exit
- max spread
- grade filter
- cooldown bars

這一層應該用來降低風險與成本，而不是硬把策略調成盈利。若 session filter 導致交易次數太少，要特別保守。

### 9.4 建議 optimization 方法

| 階段 | 方法 | 目的 |
|---|---|---|
| 粗篩 | 大步長 grid 或 genetic | 找出可能區域 |
| 穩定性檢查 | 固定幾組候選參數逐年回測 | 排除只靠單一年份的組合 |
| 細調 | 小步長 grid | 確認附近是否穩定 |
| OOS | out-of-sample / walk-forward | 檢查是否過擬合 |
| Stress | 成本、延遲、spread、swap | 檢查能不能承受真實交易摩擦 |

不要只選 optimizer 第一名。更好的候選通常是「附近多組參數都能存活」的區域，而不是孤立尖峰。

## 10. Step 7：Out-of-sample 與 walk-forward

前提：OOS 區段必須在 Step 5 screening 與 Step 6 優化「之前」就已封存（見 1.2）。若你是先用全期間挑 symbol / 參數、事後才切 OOS，那段 OOS 已經被你看過，不算真正的樣本外。

推薦至少切成：

| 用途 | 範例 |
|---|---|
| In-sample | 2020-2023 |
| Validation | 2024 |
| Out-of-sample | 2025-2026 YTD |

若策略樣本數足夠，可以做 rolling walk-forward：

```text
Train 2020-2021 -> Test 2022
Train 2021-2022 -> Test 2023
Train 2022-2023 -> Test 2024
Train 2023-2024 -> Test 2025
Train 2024-2025 -> Test 2026 YTD
```

接受標準不是每段都大賺，而是：

- OOS 不應完全失效。
- OOS drawdown 不應明顯超過 IS。
- 參數不應每段大幅漂移。
- 若最佳參數頻繁改變，代表策略 edge 可能不穩。

量化門檻建議：

- **Sharpe degradation**：`OOS Sharpe / IS Sharpe` 過低即淘汰（例如 < 0.5）；同樣方式檢查 Profit Factor 與 Expected Payoff 的衰退。
- **Walk-forward efficiency (WFE)**：`OOS 平均報酬 / IS 平均報酬`，長期低於約 0.5 代表優化主要在 fit 噪音。
- 因為前面做了大量試驗，OOS Sharpe 要用 **Deflated Sharpe Ratio（DSR）** 觀念折扣後再判讀，不能直接看名目值（見 Step 9）。

## 11. Step 8：交易成本與執行 stress test

這一步應該放在找到候選參數之後，而不是一開始就做。原因是如果策略本身沒有 edge，成本測試只會浪費時間；但若策略 edge 很薄，成本測試會決定能否繼續研究。

### 11.1 Spread test

建議測：

```text
MaxSpread = 10, 15, 20, 25, 30
```

判讀：

- 若 spread 放寬後績效變差，可能是高 spread 時段交易品質差。
- 若 MaxSpread 太低導致交易數大幅下降，可能錯過主要訊號。
- production candidate 應使用接近實際 broker 的保守設定。

不要把 MaxSpread 當作單純優化參數。它是交易品質過濾器，目標是避免劣質成交。

### 11.2 Delay / latency test

建議測：

```text
Delay = 0ms, 200ms, 500ms, 1000ms
```

若實際 VPS ping 約 200ms，就以 200ms 作 baseline，再用 500ms 與 1000ms 做 stress。

判讀：

- 如果 500ms 或 1000ms 後績效大幅惡化，策略可能過度依賴精準成交。
- 若交易數相同但 profit 下降，通常代表 entry / exit price 對 latency 敏感。
- 若差異很小，策略比較不依賴 microsecond execution，較適合一般 VPS。

### 11.3 Commission test

MT5 的 commission 通常由 broker symbol 設定決定。若 Strategy Tester 沒有正確反映 commission，可以用兩種方法：

1. 使用真實 broker demo account 的 symbol specification。
2. 建立 custom symbol，手動設定 commission / spread / swap。

研究紀錄中要另外估算 break-even extra cost：

```text
Break-even extra cost per trade = Total Net Profit / Number of Trades
```

若每筆期望值只有幾美分或幾十美分，策略很容易被 commission、slippage、wider spread 吃掉。

### 11.4 Slippage test

MT5 tester 對 slippage 的模擬能力有限，實務上應透過：

- 更高 delay 設定間接壓力測試。
- 提高 spread 或使用 broker 實際 tick data。
- 在 EA 中記錄 expected price 與 filled price，於 demo forward test 統計真實 slippage。

若策略是 breakout 或 scalping，slippage stress 的優先級要高於一般 swing strategy。

### 11.5 Swap / rollover test

若策略可能持倉跨夜，必須檢查：

- average holding time
- max holding time
- overnight trades count
- Friday holding risk
- **三倍 swap 日持倉風險**（多數 FX 在 broker 週三，部分商品週五）
- long swap 與 short swap 是否不對稱
- 所有 rollover / session 判斷以 broker server time 為準（見 1.3）

若目標是短線，建議測：

- max holding bars
- no overnight new entry
- force exit before rollover
- Friday force exit

但這些 time exit 會改變策略 payoff distribution，不能只看 profit，要同時看 trade count、expected payoff、drawdown 與 missed trend risk。

## 12. Step 9：統計穩健性與過擬合檢驗

走到這裡，策略已經有候選參數且能承受成本。但「在數百次試驗中挑出的最佳組合」本身就有 selection bias，這一步用來估計 edge 有多少機率只是運氣。

### 12.1 Monte Carlo / bootstrap

進行 Monte Carlo / DSR / PBO 前，需從 MT5 匯出 deal list / trade list 至 XLSX 或 CSV。至少保留 `entry time`、`exit time`、`symbol`、`direction`、`volume`、`profit`、`commission`、`swap`、`net profit`；若可取得，另外保留 MAE / MFE 與 entry / exit price。

- **交易序列重排**：把成交序列隨機重排多次（例如 1000 次），看 Max Drawdown 與最終權益的分布，而不是只看單一回測的 Max DD。決策應使用 DD 分布的 95th percentile，而非單點值。
- **隨機跳過交易 / bootstrap resampling**：隨機抽掉一定比例交易再重組，估出 equity curve 的信賴區間。
- **隨機進場基準**：保留原本的出場與風控，但改用隨機進場。若隨機進場績效跟策略差不多，代表 edge 來自出場/風控而非進場訊號，原假說可能不成立。

### 12.2 過擬合機率

- **Deflated Sharpe Ratio（DSR）**：用「總試驗次數」與報酬分布的 skew / kurtosis，折扣掉多重檢定帶來的虛高 Sharpe。這也是 1.2 要記錄總試驗次數的原因。
- **Probability of Backtest Overfitting（PBO，CSCV 法）**：把資料切成多段組合，檢查「IS 最佳組合在 OOS 變成後段班」的機率。PBO 偏高代表你的選擇流程本身在 fit 噪音。

### 12.3 樣本量門檻

交易數過少時，Profit Factor / Sharpe / Win Rate 都不可靠。建議硬性規則：全期至少約 200 至 300 筆，且每個主要 regime（或每年）有足夠樣本，才允許正式解讀，否則只能當 anecdotal 觀察。

### 12.4 風險指標補充

MT5 內建 Sharpe 為 per-trade、未年化、對交易頻率敏感，不可單獨引用。每個候選額外記錄：

- **Sortino、Calmar / MAR、Recovery Factor、Ulcer Index**
- **Time under water（最長水下時間）** 與 **最大連續虧損筆數**
- 尾部風險：報酬分布的 skew，必要時估 CVaR

### 12.5 組合層相關性

若同時有多個候選 symbol / 策略要上線：

- 計算候選之間 equity curve 的相關係數，避免高相關策略同時放大同一風險。
- 用合併後的 portfolio equity 重新評估整體 Max DD 與資金配置，不能只看單策略結果。

## 13. Step 10：Position sizing 與風險測試

在策略 edge 尚未穩定前，先用 fixed lot。確認策略候選後，再測 risk-based sizing。

測試順序：

1. Fixed lot 0.01：確認策略本身 edge。
2. Fixed lot 0.03 或 0.05：檢查 partial close 與 volume step 是否正常。
3. Risk % sizing：檢查止損距離與手數計算是否合理。
4. Drawdown cap：檢查連虧時是否停手。
5. Equity curve stress：檢查是否因 compounding 放大尾部風險。

若使用 partial close，最低測試手數不能太小。以 0.01 lot 測 partial close，很多 broker 會因最小手數限制導致部分平倉無法完整反映。

## 14. Step 11：保留 / 淘汰決策規則

### 14.1 可以保留研究的條件

- 全期間 profit 為正。
- 多數年度不嚴重虧損。
- Expected Payoff 大於合理交易成本 buffer。
- 參數附近區域穩定，不是單一尖峰。
- spread / delay stress 後仍可接受。
- drawdown 與持倉時間符合策略目標。
- 策略邏輯可被金融直覺解釋。
- OOS / walk-forward 未失效，Sharpe degradation 在可接受範圍。
- Monte Carlo 後的 Max DD 95th percentile 仍可承受。
- 多家 broker tick data 結果一致。

### 14.2 應暫停或淘汰的條件

- profit 主要來自單一年份或極少數交易。
- 年度結果大多接近 0，但最佳化後剛好變正。
- Expected Payoff 小到無法承受 commission / slippage。
- 參數稍微改變即失效。
- 不同 broker spread 或 delay 下表現大幅惡化。
- drawdown、持倉時間或 swap exposure 不符合原始策略目標。
- 策略需要大量特殊條件才盈利，且金融直覺薄弱。
- PBO 偏高，或 DSR 折扣後 Sharpe 不顯著。
- 隨機進場基準績效與策略相當（edge 不在進場）。
- 不同 broker tick data 結果分歧巨大。
- OOS Sharpe 相對 IS 大幅衰退。

## 15. 建議實驗命名規則

為了讓 report 可以回溯，建議檔名包含：

```text
{Strategy}-{Symbol}-{Period}-{HTF}-{DateRange}-{KeySetting}-{Delay}-{RunID}
```

範例：

```text
PS-USDJPY-M15-H1-2020_2026-MS15-MHB16-S12_16-D208.html
PS-EURUSD-M15-H1-2020_2026-MS20-MHB16-S12_16-D500.html
```

其中：

- `PS` = PrecisionSniper
- `MS15` = MaxSpread 15
- `MHB16` = MaxHoldingBars 16
- `S12_16` = Session 12 至 16
- `D208` = Delay 208ms

## 16. 每次實驗紀錄模板

````markdown
## YYYY-MM-DD - Experiment Name

### 目的

- 要驗證的假說：
- 本次只改變的參數：

### 設定

- EA：
- Indicator：
- Symbol：
- Period：
- HTF：
- Date Range：
- Modeling：
- Delay：
- Deposit：
- Lot / Risk：
- Spread / MaxSpread：
- Commission：
- Slippage assumption：
- Swap / overnight handling：
- Broker / Tick data 來源：
- Server time / DST（待確認或已確認；若採 GMT+3 / GMT+2 僅能標為假設）：
- 累計試驗次數：

### 核心 inputs

```text
InputA =
InputB =
InputC =
```

### 結果

| Metric | Value |
|---|---:|
| Net Profit | |
| Profit Factor | |
| Expected Payoff | |
| Sharpe | |
| Sortino | |
| Calmar / MAR | |
| Recovery Factor | |
| Max Drawdown | |
| MC Max DD p95 | |
| Max 連續虧損筆數 | |
| Time under water | |
| Trades | |
| Win Rate | |
| Avg Holding Time | |

### 解讀

- 是否支持原假說：
- 主要改善：
- 主要風險：
- 是否需要年度切片：
- 是否需要 cost stress：

### 決策

- Keep / Retest / Reject：
- 下一步：
````

## 17. 建議研究順序摘要

若是新策略，建議固定採用以下順序：

1. 先寫清楚 strategy hypothesis。
2. 先切走並封存 OOS 區段，後續 screening / 優化不得使用。
3. 檢查 indicator buffer 與 EA execution safety。
4. 跑 1 至 3 個月 smoke test。
5. 跑一個主要 symbol 的 development-period baseline；不要使用已封存 OOS。
6. 做年度切片。
7. 測 M15、M15+H1、H1、H1+H4；H4 只作 benchmark。
8. 固定 inputs 跑 major FX symbol screening。
9. 選 1 至 3 個候選 symbol 做參數粗優化。
10. 對候選參數做年度、OOS、walk-forward。
11. 做 spread、delay、commission、slippage、swap stress test。
12. 用第 2 家 broker tick data 驗證候選參數，檢查是否對單一 broker 報價過度敏感。
13. 做 Monte Carlo、DSR、PBO 統計穩健性檢驗。
14. 測 fixed lot 放大與 risk-based sizing，並評估 portfolio 相關性。
15. 做 demo forward test，收集真實 spread、slippage、execution retcode；設定最短時長與 live-vs-backtest 偏離容忍門檻。
16. 最後才決定是否成為 production candidate。

## 18. 對短線 FX 策略的特別規則

短線策略的主要敵人通常不是方向判斷，而是交易成本與執行品質。

因此若目標是 M15 / H1：

- 優先測 major FX，不優先從 exotic 或高 spread 商品開始。
- 優先測 session filter，例如 London / New York overlap。
- 必須測 MaxSpread。
- 必須測 Delay。
- 必須估算 break-even extra cost per trade。
- 必須檢查持倉是否跨 rollover。
- 必須逐年測，而不是只看總期間。
- 若每年交易數太低，不能過度解讀最佳化結果。
- session filter 一律以 broker server time 為準，並注意夏/冬令位移（見 1.3）。
- 必須檢查週三三倍 swap 日的持倉。

實務上，短線策略若無法承受 500ms delay、合理 commission、以及常見 spread 擴大，通常不適合作為 live candidate。
