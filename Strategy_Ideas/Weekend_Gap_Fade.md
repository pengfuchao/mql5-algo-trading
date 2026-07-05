# 週末跳空回補（Weekend Gap Fade）策略想法

建立日期：2026-07-04

狀態：Phase 0 short-sample 通過但樣本不足（MetaQuotes-Demo M15 只回到 2022-06）；依個人盤面觀察改走 **research prototype / demo-forward only** 路線，已新增 `Strategies/Strategy_Weekend_Gap.mq5` 供 demo 蒐集真實執行證據。尚未通過正式 Phase 1 backtest gate，**不得視為 live-ready**。

## 1. 核心想法

FX 市場週末休市，週一開盤價與上週五收盤價之間常有跳空（gap）。坊間統計普遍宣稱「多數週末跳空會回補」（價格回到上週五收盤價）。策略：

```text
週一開盤跳空 ≥ 閾值 → 反跳空方向進場 → TP = 上週五收盤價
```

- 向上跳空 → 開空，目標 = 上週五收盤價。
- 向下跳空 → 開多，目標 = 上週五收盤價。
- 每週最多一筆、每筆持倉最多 1–2 天 → 極低頻策略。

與時段效應想法同類：**零指標、時間+價格結構驅動、參數面積近零**。

## 2. 策略假說

- 週末跳空多數由低流動性的週一亞洲早盤定價形成（做市商在薄市中掛出的開盤價），而非真實資訊定價。
- 無重大週末新聞時，跳空是「定價噪音」，週一流動性回升後傾向被修正（回補）。
- 有重大週末事件（選舉、地緣衝突、央行突發）時跳空是真實 repricing，**不會回補** —— 這種「breakaway gap」是本策略的主要虧損來源。

## 3. 外部實證（誠實：比坊間宣稱弱）

- **[EarnForex 週跳空統計](https://www.earnforex.com/guides/forex-weekly-gap-statistics/)**：7 大主要貨幣對、2010–2025 共 **797 週**的系統統計。關鍵發現偏反面：**跳空大小與前後波動性之間找不到相關性**，即「用跳空大小預測後續行為」的常見規則缺乏統計支持。該研究也**沒有**給出「X% 會回補」的正面數字。
- **[TradeThatSwing EURUSD 週一 gap fill 統計](https://tradethatswing.com/eurusd-monday-gap-fill-strategy-and-statistics/)**：EURUSD 專門的 gap fill 統計與策略（存取受限未能核實具體數字，列為待查證來源）。
- **從業者共識**（[EarnForex gap 交易指南](https://www.earnforex.com/guides/how-to-trade-weekend-gaps-in-forex/)、[DayTrading.com](https://www.daytrading.com/forex/weekend-trading)）：小型「common gap」多在數小時至數日內回補；帶基本面催化的「breakaway gap」可能永不回補 —— 但這些是敘事，不是可核實的回測。
- 判讀：**「回補傾向」方向上可信（均值回歸 + 薄市定價噪音的機制合理），但強度與勝率沒有可靠的公開數字**。本想法的第一步不是寫 EA，而是自己跑統計（見第 7 節）—— 這正好是 MT5 歷史資料能直接回答的問題。

## 4. 進場條件（機械化定義）

- **跳空定義**：週一第一根 M15 開盤價 vs 上週五最後一根 M15 收盤價（server time）。
- **閾值**：`|gap| ≥ max(固定 pips 下限, 0.3 × ATR(D1))` —— 太小的 gap 扣掉點差無利可圖。固定下限初值：EURUSD 5 pips。
- **上限**：`|gap| ≤ 1.5 × ATR(D1)` —— 超大跳空視為 breakaway（真實 repricing），**不交易**。這條規則直接對應第 2 節的失效假說。
- **進場時機**：週一開盤後第 1 根 M15 收盤時進場（不搶第一 tick —— 開盤瞬間點差極寬且常有毛刺）。
- 方向：反跳空方向。每週最多 1 筆。

## 5. 過濾條件

- `MaxSpread`：週一開盤點差常態性暴寬，**必須等點差回到正常水位才進場**（例如連續 3 根 M1 點差 < 閾值），否則成本直接毀掉策略。
- 已知重大週末事件（選舉週末）選配跳過；第一版不加（讓上限規則先扛）。

## 6. 出場與風控

- **TP**：上週五收盤價（gap 完全回補）。可選 80% 回補提前出場（回補常在最後一段變慢），第二輪再 A/B。
- **SL**：`1.0 × |gap|` 反向距離（RR 約 1:1）或 `1.0 × ATR(D1)`，取較近者。
- **時間出場**：週三 00:00 server time 未觸 TP/SL 一律平倉 —— 回補論的機制（薄市定價噪音修正）只在開盤後短窗口有效，拖過兩天就不是這個假說了。
- 無隔夜 swap 顧慮以外的特殊風控（持倉最長 2 天，swap 成本要算進回測）。

## 7. 第一輪測試計畫

1. **先跑統計、後寫 EA**（本想法最大優點：假說可以先用純統計證偽，不用寫交易邏輯）：
   - 用 MQL5 腳本或 Python 掃 EURUSD / USDJPY / GBPUSD 2015–2026 的每個週一：gap 大小、是否回補、回補耗時、最大反向偏移（MAE）。
   - 產出表：按 gap 大小分桶的回補率與 MAE 分布。**若 5–30 pips 桶的回補率 < 65%，或 MAE 中位數 > gap 大小，直接結案不寫 EA。**
2. 統計通過才寫 EA baseline：固定參數（第 4–6 節初值），2015.01–2026.06，real ticks。
3. 成本壓測重點：**週一開盤點差情境**（正常 / ×2 / ×3）+ 持倉過夜的 swap。
4. 樣本量預估：11.5 年 × 52 週 × 過濾後約 40% 觸發率 ≈ 240 筆/商品 —— 樣本勉強夠，**不可再加過濾切碎樣本**。

### 7.1 目前統計結果（2026-07-06）

實際執行 `Utilities/Script_Weekend_Gap_Stats.mq5` 後，MetaQuotes-Demo 的 M15 歷史只涵蓋 **2022-06-27 至 2026-06-29**，不是檔名中的 2015–2026。H1 可回到 2010，但不能替代 M15，因為本策略的 gap 定義、回補時間與 MAE 都依賴週五最後一根 M15 與週開盤第一根 M15。

短樣本 5–30 pips 桶結果：

| Symbol | Samples | 48h fill rate | Median gap | Median MAE | 判讀 |
|---|---:|---:|---:|---:|---|
| EURUSD | 104 | 94.2% | 9.40 pips | 3.95 pips | short-sample pass |
| USDJPY | 120 | 96.7% | 11.25 pips | 3.65 pips | short-sample pass |
| GBPUSD | 128 | 95.3% | 11.30 pips | 2.40 pips | short-sample pass |

限制：樣本只有約 4 年，不能滿足原本 2015–2026 的正式統計關；large gap 的行為也不穩定（例如 30–50 / >50 pips 桶明顯較弱）。因此決策改為：**不晉級 live candidate，不建立正式通過紀錄；只做 prototype EA 在 demo forward 蒐集週一開盤 spread、slippage、fill quality 與實際回補證據。**

## 8. 可能風險與失效條件（誠實評估）

**結論：機制合理、規則極簡、可先用純統計低成本證偽 —— 是很好的「方法論練習題」；但公開證據弱於傳說，且極低頻使它就算成立也只是組合裡的小配菜。**

正面：
- **可先統計後實作**：全 backlog 唯一能在寫 EA 前就用歷史資料直接證偽的想法，研究成本最低。
- 零指標、參數面積近零（閾值上下限 + SL 規則），過擬合空間小。
- 每週最多一筆、與 repo 所有既有策略（日內時段型、突破型）時間上幾乎不重疊，組合互補。
- 失效模式明確可規則化（breakaway gap → 用 gap 上限排除）。

保留意見：
- **公開統計不支持強效應**：EarnForex 797 週研究找不到跳空的可預測結構 —— 「必回補」很可能是倖存者敘事。第 7 節第 1 步的自建統計是唯一可信依據。
- **極低頻 = 樣本累積慢**：就算回測通過，forward 驗證要以「年」計；且 240 筆的回測樣本對 PF 估計的信賴區間很寬。
- 尾部風險集中：虧損集中在地緣事件週末（gap 上限規則能擋大部分，但事件夜的滑價與點差會讓實際 SL 比回測差）。
- 週一開盤的回測資料品質是已知弱點：real ticks 在開盤前幾分鐘的點差記錄未必反映真實可成交價，**回測結果要打折看**。

## 9. 進入 `Strategy_Records/` 的條件

- 第 7 節統計關通過（5–30 pips 桶回補率 ≥ 65% 且 MAE 中位數 < gap）。
- EA baseline 含週一開盤點差 ×2 壓測後 PF ≥ 1.15。
- 虧損分布檢查：無單一事件週末貢獻超過年度虧損的一半（尾部不失控）。
- 三商品中至少兩個方向一致（排除單商品巧合）。

## 相關文件

- 同為時間結構型想法：[FX_TimeOfDay_Effect.md](FX_TimeOfDay_Effect.md)、[London_Breakout_Asian_Range.md](London_Breakout_Asian_Range.md)
- 訊號日重疊注意：[Asian_Session_Mean_Reversion.md](Asian_Session_Mean_Reversion.md)（該策略須跳過週一凌晨，避免 gap 汙染區間）
- 決策標準與研究流程：[../Strategy_Records/MT5_Strategy_Research_Workflow.md](../Strategy_Records/MT5_Strategy_Research_Workflow.md)

## 外部參考

- [EarnForex — Forex Weekly Gap Statistics（2010–2025、797 週、7 大貨幣對）](https://www.earnforex.com/guides/forex-weekly-gap-statistics/)
- [EarnForex — How to Trade Weekend Gaps in Forex](https://www.earnforex.com/guides/how-to-trade-weekend-gaps-in-forex/)
- [TradeThatSwing — EURUSD Weekend Gap Fill Strategy and Statistics（待查證）](https://tradethatswing.com/eurusd-monday-gap-fill-strategy-and-statistics/)
- [DayTrading.com — Forex Weekend Trading Tutorial](https://www.daytrading.com/forex/weekend-trading)

---

## 10. 實作規劃（給 Codex 的 spec）

### Phase 0：統計掃描腳本（先做；統計關不過就沒有 Phase 1）

**交付物**：`Utilities/Script_Weekend_Gap_Stats.mq5`（MQL5 Script，非 EA/指標）

**目前進度（2026-07-06）**：已完成 `Utilities/Script_Weekend_Gap_Stats.mq5`，MetaEditor 編譯結果 0 errors / 0 warnings。CSV 已執行並審視；5–30 pips 桶在 2022-06–2026-06 short sample 通過，但 M15 長樣本不足，正式 Phase 0 gate 未完整成立。

**功能**：掃描指定商品的 M15 歷史，對每個「週開盤」輸出一列統計，寫 CSV 到 `MQL5/Files/`。

**Inputs**：`InpSymbols`（string / `"EURUSD;USDJPY;GBPUSD"`，分號分隔）、`InpStartDate`（2015.01.01）、`InpEndDate`（2026.06.30）、`InpFillWindowHours`（48）。

**核心邏輯**：
1. 對每個 symbol 逐一 `CopyRates`（M15）取全期間。
2. **週界定義**：「上週最後一根」= 週五（server dayofweek=5）最後一根 M15；「本週第一根」= 其後第一根 bar（**不要假設是週一 00:00**——多數 broker 週日晚間即有報價，直接取時間序列上的下一根即可）。兩根間隔 < 24h 視為同週（假日誤判防護），跳過。
3. 每週輸出欄位：`week_open_time, prev_close, week_open, gap_points, gap_pips, gap_vs_ATRD1`（ATR(D1,14) 取上週五收盤時值）、`filled_24h, filled_48h`（開盤後 24/48h 內是否觸及 `prev_close`）、`bars_to_fill`、`MAE_pips`（回補前的最大反向偏移：向上跳空時為開盤後、觸及 prev_close 前的最高價−開盤價；向下鏡像；未回補則取窗口內極值）。
4. 結尾在 Experts log 印分桶彙總表：gap 大小桶（<5 / 5–15 / 15–30 / 30–50 / >50 pips）× {樣本數, 48h 回補率, MAE 中位數, bars_to_fill 中位數}，每 symbol 一表。

**驗收標準**：編譯 0/0；EURUSD 全期間週數 ≈ 590±10（11.5 年）；CSV 可開；抽查 3 週的 gap 與 MT5 圖表人工核對一致。

**統計關（由我審視 CSV 後判定）**：5–30 pips 桶 48h 回補率 ≥ 65% 且 MAE 中位數 < gap 中位數，至少兩個 symbol 成立 → 進 Phase 1；否則本想法結案。

### Phase 1（research prototype）：EA

**交付物**：`Strategies/Strategy_Weekend_Gap.mq5`

**目前進度（2026-07-06）**：已新增 prototype EA。此版本是 demo-forward evidence collector，不是正式通過統計關後的 live candidate。研究用途是記錄真實週一開盤執行品質，並驗證短樣本觀察是否延續。

**Inputs**：

| Input | 預設 | 說明 |
|---|---|---|
| `InpMinGapPips` / `InpMinGapATRMult` | 5 / 0.3 | 閾值取兩者較大 |
| `InpMaxGapATRMult` | 1.5 | 超過視為 breakaway，不交易 |
| `InpEntryDelayBars` | 1 | 週開盤後第 N 根 M15 收盤才進場 |
| `InpEntryWindowMins` | 60 | 只允許週開盤後短窗口內進場 |
| `InpSpreadCalmBars` | 3 | 連續 N 根 M1 點差 < `InpMaxSpreadPts` 才允許進場 |
| `InpTPMode` | FULL_FILL | FULL_FILL（prev_close）/ PARTIAL_80 |
| `InpSLGapMult` / `InpSLATRMult` | 1.0 / 1.0 | SL 以 gap 倍數為主，並受 D1 ATR cap 限制 |
| `InpForceCloseDay/Hour` | 週三 00:00 | 時間出場 |
| `InpFixedLots` / `InpRiskPercent` / `InpMagic` | 0.01 / 0 / 770040 | 預設 demo fixed lot；若 `InpRiskPercent>0` 才用風險手數 |

**核心邏輯**：偵測「週開盤」（同 Phase 0 定義，用 bar 間隔 > 24h 且上一根為 Friday 判定）→ 計算 gap → 過濾（閾值/上限/點差平靜）→ 反 gap 方向市價單，TP = prev_close 或 80% 回補、SL 依 gap/ATR → 觸 TP/SL 或週三強平。每週最多 1 筆/symbol；已交易週會用 terminal Global Variable 記錄，避免 EA 重啟後同一週重複進場。閒置時間直接 return（本 EA 一週只活躍幾小時）。

**驗收標準**：編譯 0/0；tester 全年交易數 ≤ 52；每筆進場時間都在週開盤後 1 小時內；`TP_FULL_FILL` 時 TP 價位 = 上週五收盤價（抽查 5 筆）；gap 超上限的週有 `skipped: breakaway` log。

### Phase 2：測試協定

三 symbol 各跑 2015.01–2026.06 real ticks；成本情境：原始 / 週一開盤點差 ×2 / ×3（重點壓測）；swap 納入。通過標準見第 9 節。**提醒：真實成交品質在週開盤時段的回測可信度偏低，結果打折看（第 8 節）。**
