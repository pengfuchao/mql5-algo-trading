# 黃金日內季節性（亞洲盤漲 / 歐美盤跌）策略想法

建立日期：2026-07-04

狀態：**已驗證／否定，結案（2026-07-20）**。MAIN 正式回測完成：edge 僅 `0.110 USD/oz` < 中性成本 `0.29 USD/oz`，**G1 成本關卡不通過**（成本後 PF 0.956）；原始 PF 亦僅 1.028、Sharpe 0.339；逐年 9 年中 6 年為負、利潤集中 2024–2025，符合第 8 節事前寫下的「只是 gold beta」失效模式。依事前規則 CTRL-1/2/3 未執行。完整結果見 [Strategy_Records/Strategy_Time_Window.md](../Strategy_Records/Strategy_Time_Window.md)

## 1. 核心想法

黃金最著名的日內異象：**「亞洲時段上漲、倫敦/紐約時段（尤其 London PM Fix 前後）下跌」**。

```text
亞洲時段（東京開盤 → 倫敦開盤前）   → XAUUSD 傾向緩漲 → 做多窗口
倫敦下午（PM Fix 15:00 UTC 前後）   → 歷史上系統性走弱 → 做空/避開窗口
```

成因假說：
- 亞洲實體需求（中國、印度是全球最大黃金消費國）集中在亞洲時段買入。
- London PM Fix（15:00 UTC）是全球機構定價基準，生產商/央行的賣壓歷史上集中在 fix 前後執行。

與 FX 時段效應同屬**時段 × 訂單流**類策略：零指標、參數面積極小。

## 2. 策略假說

- 實體供需的時區分布（亞洲買、倫敦定價賣）造成日內回報的系統性不對稱。
- 只在多頭窗口持多倉（或加上倫敦下午空倉），長期累積正漂移。
- 預期：與 FX 時段效應一樣是「薄而穩」型，單筆期望小、靠頻率累積；黃金波動大於 EURUSD，單位時間期望絕對值較大，但尾部風險也大。

## 3. 外部實證（寫想法前先查證過）

- **Dimitri Speck 的長期統計**：分析多年 1 分鐘金價資料，發現 **London PM Fix 前後有清晰、系統性的下跌傾向**，且「亞洲漲、歐美跌」模式被觀察超過 30 年（見 [COPI TOOLS 對 XAUUSD 異象的整理](https://copi-tools.com/blog/xauusd-anomaly/)）。Speck 著有 *The Gold Cartel*，其日內季節性圖表是此領域最常被引用的證據。
- **學術支持（fix 異象）**：Caminschi & Heaney (2014), *Fixing a Leaky Fixing*（Journal of Futures Markets）記錄 London PM Fix 期間的異常價格行為；2014 年後 fix 改制為 LBMA 電子拍賣，**改制後異象強度需重新驗證** —— 這是本想法最大的不確定性。
- **旁證**：[QuantifiedStrategies — Gold Overnight Strategy](https://www.quantifiedstrategies.com/gold-overnight-trading-strategy/) 指出黃金（以美國市場時間計）**正報酬集中在 overnight（= 亞洲時段）**，與 Speck 模式一致；但也警告 gold 是極難交易的資產，多數策略死於成本與 regime。
- 判讀：模式的歷史紀錄很長，但 (a) 2014 fix 改制、(b) 2022–2026 央行購金潮改變供需結構 —— **近 5 年子樣本驗證是第一關，過不了就直接結案**。

## 4. 進場條件（機械化定義）

以 UTC 定義（黃金以 UTC 錨定比 London/NY time 乾淨），實作換算 server time：

- **多頭窗口（主要）**：00:00 UTC（東京早盤）開多 XAUUSD，07:00 UTC（倫敦開盤前）平倉。
- **空頭窗口（選配，第二階段才測）**：13:00 UTC 開空，17:00 UTC 平倉（覆蓋 PM Fix 15:00 UTC 前後）。
- H1 執行，定時進出，無價格條件。
- 第一版**只測多頭窗口** —— 空 gold 在 2022–2026 央行購金 + 多頭大 regime 下屬於逆勢，先驗上更危險。

## 5. 過濾條件

- `MaxSpread`（亞洲時段 XAUUSD 點差偏寬，本策略成本敏感）。
- 跳過重大事件日（FOMC 日的亞洲時段常反常）—— 選配，第一版可不加。

## 6. 出場與風控

- 定時平倉為主；災難 SL = `ATR(D1) × 1.5` 遠端保護。
- 固定小手數。黃金單日可動 2–3%，**部位必須比 FX 時段策略小一號**。
- 無隔夜倉（窗口都在日內），避開 swap（XAUUSD swap 通常很貴，這是日內化的實質好處）。

## 7. 第一輪測試計畫

1. **零參數 baseline**：`XAUUSD / H1`，多頭窗口 00:00–07:00 UTC，期間 2015.01–2026.06，real ticks，含真實點差。
2. **年度拆分是本策略的核心測試**：分 2015–2019（fix 改制後、購金潮前）與 2020–2026 兩段看效應穩定性。若效應只存在 2022 後 → 那只是黃金大多頭的 beta，不是時段 alpha；**對照組：同期「隨機 7 小時窗口」或「全日持有 1/3 部位」的報酬，必須顯著優於對照才算數**。
3. 成本壓測：亞洲時段點差 ×1.5 / ×2。
4. 通過後才測空頭窗口（PM Fix 空單）作為獨立假說。

## 8. 可能風險與失效條件（誠實評估）

**結論：歷史紀錄最長的日內異象之一，但兩個結構性變化（fix 改制、央行購金）可能已改寫它 —— 當「便宜的驗證題」跑，不當金礦。**

正面：
- 30 年級別的紀錄長度，遠超一般零售策略傳說。
- 機制（亞洲實體買盤 / 倫敦定價賣壓）有真實供需解釋。
- 零指標、近零參數，過擬合面積極小。
- 與 repo 既有全部策略不相關；且與 FX_TimeOfDay 想法共用同一個 EA 骨架（定時進出引擎），**寫一次程式可以測兩個想法**。

保留意見：
- **2014 fix 改制**：Speck 的最強證據多來自改制前；電子拍賣後 fix 前後的異象可能已大幅衰減。
- **2022–2026 央行購金潮**：供需結構已變，歷史模式外推風險高；多頭窗口若賺錢，必須用對照組排除「只是 gold beta」。
- 亞洲時段點差寬 + 單筆期望薄 = 和 FX 時段效應一樣，**可能死在零售成本**。
- 黃金尾部風險：持倉窗口內遇到地緣事件，災難 SL 可能大幅滑價。

## 9. 進入 `Strategy_Records/` 的條件

- 2015–2026 全樣本正期望，且 **2020–2026 子樣本獨立成立**（效應未死）。
- 顯著優於「隨機窗口 / 縮小部位全日持有」對照組（證明是時段 alpha 不是 beta）。
- 亞洲時段點差 ×1.5 壓測後仍正期望。
- 回撤形狀為緩慢累積型，無單一事件貢獻主要利潤。

## 相關文件

- 決策標準與研究流程：[../Strategy_Records/MT5_Strategy_Research_Workflow.md](../Strategy_Records/MT5_Strategy_Research_Workflow.md)
- 共用定時進出引擎的姊妹想法：[FX_TimeOfDay_Effect.md](FX_TimeOfDay_Effect.md)
- 同為時段型想法：[London_Breakout_Asian_Range.md](London_Breakout_Asian_Range.md)

## 外部參考

- [COPI TOOLS — Gold Price Seasonality / XAUUSD 日內異象整理（含 Speck 研究）](https://copi-tools.com/blog/xauusd-anomaly/)
- [QuantifiedStrategies — Gold Overnight Strategy: Rules & Backtest](https://www.quantifiedstrategies.com/gold-overnight-trading-strategy/)
- [QuantifiedStrategies — Top Gold Trading Strategies (Backtests)](https://www.quantifiedstrategies.com/gold-trading-strategies/)

---

## 10. 實作規劃（給 Codex 的 spec）

**目前進度（2026-07-20）**：已確認不另寫新 EA，復用 `Strategies/Strategy_Time_Window.mq5`。為支援 CTRL-3「03:00 開、次日 03:00 平」的 24h gold beta control，EA 新增 `InpAllowFullDayWindow` opt-in；預設關閉，不影響 FX Time-of-Day 或一般日內 window。已建立 MAIN + CTRL-1/2/3 四組 research `.set` preset。點差校準已完成、`InpMaxSpreadPts` 已定案為 `22.5`（見下方「點差校準結果」）。同一次校準發現**歷史深度不足**，導致 §9 的跨 regime 驗證無法執行，本次實驗改採 regime-limited 判定（見下方「歷史深度限制」）。下一步是依修正後的測試協定跑 XAUUSD H1 formal backtest。

### 點差校準結果（2026-07-20）

工具：`Utilities/Script_XAUUSD_Session_Spread_Calibration.mq5`（掃 M1 歷史的 `MqlRates.spread`，單位 points）。

- `digits=2`、`point=0.01` → **1 point = 0.01 USD/oz**，與 `Strategy_Time_Window.mq5` 的 `(ask-bid)/_Point` 單位一致。
- MAIN 窗口（server 03:00–10:00）：median `15`、p90 `17`、p95 `18`（近 1.5 年完整樣本）。
- 定案：**`InpMaxSpreadPts = 22.5`**（median 15 × 1.5），四組 preset 統一使用。
- 統一值的理由：gate 只在開倉時檢查，而四組的開倉時刻 median 為 15/15/13/15、p95 皆為 18，統一 gate 讓各組擋單率幾乎相同，**避免差別進場率污染 MAIN vs CTRL 的比較**。

⚠️ **此數字只能當 spike gate，不能當黃金交易成本的證據**：demo 歷史點差呈現合成特徵（24 小時 median 幾乎全平、`avg < median` 代表分布被量化成少數離散值），與真實 XAUUSD「亞洲盤寬、歐美重疊時段緊」的日內形狀不符。成本結論必須另以實盤點差取得。

成本數量級（供回測後對照）：0.01 lot = 1 oz，spread 15 points = **$0.15/round-turn**，約 250 筆/年 → **$37.5/年**。若亞洲盤 7 小時的方向性漂移只有 $0.1–0.3/oz 級別，成本與毛利同一數量級。**回測後必須先用 `Net Profit / Trades` 算 break-even，再看淨利**，避免重蹈 FX Time-of-Day 死在成本上的覆轍。

### 歷史深度限制與 regime-limited 判定（2026-07-20，當日修正）

**初版判定（已作廢）**：曾依 XAUUSD **M1** 歷史上限 981,289 根推論可用區間僅約 `2023.10–2026.06`（2.7 年）。**該推論錯誤** —— 那是 M1 的限制，本 EA 跑在 H1 且進出場在固定時刻，M1 深度不是綁定條件。

**實測修正**：由一次 XAUUSD H1 tester run 的委託明細確認，實際可成交區間為 **2018.01.29–2026.06.29（約 8.4 年）**，H1 bars 64,776 根。逐年委託數：

| 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026H1 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1000 | **304** | 1554 | 1866 | 1860 | 1800 | **1178** | 1752 | 910 |

因此：

- **2019 與 2024 有明顯 tick 資料缺口**（正常年約 1800），tester 報告的「質量歷史 68% 真實報價」即反映此事。這兩年的統計必須標註為不完整年份，**不可當完整年份納入穩定性判斷**。
- **2015–2017 完全無資料**，第 9 節原訂的 `2015–2019 vs 2020–2026` 拆分仍**無法照原樣執行**。
- **但 regime 對比是可行的**：改以 `2018–2021`（購金潮前 / 早期）vs `2022–2026`（央行購金潮）兩段拆分，正好切在結構性變化點上。
- 樣本量充足：MAIN 每交易日 1 筆，8.4 年扣除缺口 ≈ **1800 筆**。

**修正後的 pre-registered 判定**：

| 結果 | 判定 |
|---|---|
| MAIN 未通過成本關卡（見下節 G1） | **結案**，不再跑 CTRL 對照。 |
| MAIN 未贏過 CTRL-1/2/3 | **結案**。第 8 節的「只是 gold beta」成立。 |
| MAIN 全關通過，且 `2018–2021`／`2022–2026` 兩段皆成立 | 可寫入 `Strategy_Records/` 並討論晉級。 |
| MAIN 全關通過，但效應只存在 `2022–2026` | **記為 beta 假象，結案**（原第 9 節精神保留）。 |

### G1 — 成本關卡（pre-registered，MAIN 跑完後立即執行，**先於 CTRL 對照**）

理由：`Strategy_Session_Range` 已示範一條 OOS 表現良好（OOS PF 1.235）的策略仍可因毛 edge 小於成本而結案。黃金這條線的單位報酬更薄，**必須先過成本關才值得跑對照組**。

**單位換算**：`InpFixedLots=0.01`，XAUUSD 1.0 lot = 100 oz → **0.01 lot = 1 oz**。因此 tester 報告的「預期收益（Expected Payoff, USD/trade）**在數值上等於每筆 edge 的 USD/oz**」。這讓成本比較非常直接。

**回測已含 / 未含**：real ticks 回測已包含 demo 點差；**未包含** commission、slippage，也未反映 demo 點差可能低估真實點差（見上方「點差校準結果」的合成資料紅旗）。

額外成本假設（round-turn, USD/oz）：

| 項目 | 樂觀 | 中性 | 保守 |
|---|---:|---:|---:|
| Commission（`$7/lot` RT ÷ 100 oz）| 0.00 | 0.07 | 0.07 |
| Slippage | 0.03 | 0.07 | 0.15 |
| 真實點差 − demo 點差（demo median 0.15）| 0.00 | 0.15 | 0.25 |
| **合計 additional cost** | **0.03** | **0.29** | **0.47** |

**判定公式**（`GP`、`GL`、winners、losers 取自 MAIN 報告）：

```text
PF' = (GP − winners × cost) / (GL + losers × cost)
```

**事前門檻**：

| 條件 | 判定 |
|---|---|
| 中性情境 `PF' < 1.10` | **結案**，不跑 CTRL。低波動高頻策略 PF 天花板本就低，門檻沿用 FX 檔第 9 節的 1.10 而非 1.15 |
| 中性 `PF' ≥ 1.10` 但保守情境 `PF' < 1.00` | 記為 **cost-marginal**，僅可繼續研究，**不得晉級** |
| 中性 `PF' ≥ 1.10` 且保守 `PF' ≥ 1.00` | 通過 G1，進 CTRL 對照 |

**快速預檢**：若報告的「預期收益」`< 0.29 USD/trade`，中性情境下 edge 已被成本吃光，可直接判結案，不必算 `PF'`。

⚠️ 註記：cost 對 MAIN 與 CTRL-3 的**每筆**影響相同，但 MAIN 每筆只持倉 7h、CTRL-3 持倉 24h，因此**以「報酬/持倉小時」比較時成本對 MAIN 的傷害更大**。CTRL-3 對照必須用**成本後**數字計算，不可用原始報告數字。

共通原則：**歷史或樣本的不足會削弱「通過」的可信度，但不削弱「否定」的可信度。** 因此任何一關的否定結論都直接生效、可據以結案；通過則需累積全部關卡才算數。

### 前置條件

依賴 `Strategies/Strategy_Time_Window.mq5`（定時進出引擎，spec 見 [FX 時段效應檔 §10 Phase 1](FX_TimeOfDay_Effect.md)）。**本檔不需要新程式**——只是該 EA 的另一組配置 + 一套對照實驗設計。若引擎驗收通過，本策略的「實作」只剩準備 `.set` 檔。

### 配置（XAUUSD 主實驗）

| Input | 值 | 說明 |
|---|---|---|
| `InpUseWindowA` | true | 多頭窗口（唯一窗口，第一版不開空頭） |
| `InpWindowADir` | BUY | |
| `InpWindowAOpenHour/Min` | 3, 0 | = 00:00 UTC（**夏令 EET+3 時**；冬令偏移 1h，v1 接受，註記在 report） |
| `InpWindowACloseHour/Min` | 10, 0 | = 07:00 UTC |
| `InpUseWindowB` | false | 空頭窗口（PM fix）第二階段才開 |
| `InpFixedLots` | 0.01 | **比 FX 配置小一號的精神**：XAUUSD 0.01 lot 已是最小 |
| `InpCatastropheATRMult` | 1.5 | 黃金尾部風險較大，SL 較近（vs FX 的 2.0） |
| `InpMaxSpreadPts` | **`22.5`（已定案）** | 校準自 M1 歷史點差 median 15 × 1.5；四組 preset 統一。詳見上方「點差校準結果」 |
| `InpAllowFullDayWindow` | false | MAIN/CTRL-1/CTRL-2 不需要；CTRL-3 需設 true |
| `InpMagic` | 770021 | |

Presets：

| Run | Preset | 用途 |
|---|---|---|
| MAIN | `../Strategy_Records/Strategy_Time_Window_XAUUSD_Gold_MAIN.set` | 亞洲時段 BUY 03:00–10:00 server（**保留**：本線結案證據的重現依據）|
| CTRL-1/2/3 | *（2026-07-20 已刪除）* | MAIN 未通過 G1 成本關卡，依事前規則對照組不執行。窗口定義保留於下方「對照實驗設計」表，未來若以更深歷史重啟，可依該表於數分鐘內重建 |

`InpMaxSpreadPts` 已於 2026-07-20 完成校準並由佔位值 `300.0` 更新為 `22.5`，point size 與等價美元/oz 點差記錄於上方「點差校準結果」。

### 對照實驗設計（本策略的核心，第 7 節第 2 步的具體化）

主實驗通過「表面正期望」後，**必須**跑以下對照組（同引擎、只改窗口/方向，各自獨立 tester run）：

| Run | 窗口（server, 夏令） | 目的 |
|---|---|---|
| MAIN | BUY 03:00–10:00 | 主假說（亞洲時段多頭漂移） |
| CTRL-1 | BUY 10:00–17:00 | 倫敦上午（假說預期：明顯差於 MAIN） |
| CTRL-2 | BUY 17:00–24:00 | 美盤（假說預期：差於 MAIN） |
| CTRL-3 | BUY 全日持有（03:00 開、次日 03:00 平）、手數同 | gold beta 對照：MAIN 的年化/回撤必須優於「持有 beta 的 7/24 等比例」，否則只是搭多頭便車 |

判定：`MAIN 的 Sharpe > CTRL-1、CTRL-2`，且 `MAIN 的報酬/持倉小時 > CTRL-3 的報酬/持倉小時 × 1.5`，效應才算「時段 alpha」。任何一條不成立 → 第 8 節的「只是 gold beta」結論，結案。

### 年度拆分重點（第 7 節第 2 步）

**原設計**：2015–2019（fix 改制後、購金潮前）與 2020–2026 兩段分開報告；若 alpha 只存在 2022 之後 → 記錄為 beta 假象，結案。

**2026-07-20 修正**：2015–2017 無資料，原訂拆分無法照原樣執行。改以 **`2018–2021` vs `2022–2026`** 兩段拆分（切在央行購金潮前後），並逐年列出。**2019 與 2024 有 tick 缺口（委託數僅約正常年的 17% / 65%），必須標註為不完整年份**，不可用於穩定性判斷。beta 判別仍由 CTRL-3 承擔。

### 測試協定

- XAUUSD H1，**2015.01–2026.06（tester 會自動對齊到 2018.01 起的實際可用資料）**，real ticks，10000 USD，1:100，0.01 lot。
  - ⚠️ **開跑前**必須在「輸入參數」分頁按「載入」選對 preset，並肉眼確認 `InpWindowADir=0 (BUY)`、`03:00–10:00`、`InpUseWindowB=false`。2026-07-20 曾發生未載入 preset、以 EA 預設值（FX Time-of-Day 配置：Window A SELL 10:00–18:00 + Window B BUY）誤跑的情況，該 run 作廢。
  - ⚠️ 跑完必須核對報告開頭的 inputs 區塊與 model quality，確認 preset 生效且未退回模擬 tick。
- 成本情境：原始 / 亞洲時段點差 ×1.5 / ×2。
- 產出物：MAIN + 3 CTRL 共 4 份 report（×3 成本情境的 MAIN），依 `Strategy_Records/` 慣例命名；逐年拆分表。
- 通過標準見第 9 節，**但以上方「歷史深度限制」的修正判定表與「G1 成本關卡」為準**（執行順序：G1 → CTRL 對照 → regime 拆分）。
- 空頭窗口（13:00–17:00 UTC 覆蓋 PM fix）**只有 MAIN 全關通過後**才作為獨立假說開 Window B 測試。
