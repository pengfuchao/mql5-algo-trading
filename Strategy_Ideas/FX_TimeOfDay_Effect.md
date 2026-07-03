# FX 時段效應（本地時段貶值異象）策略想法

建立日期：2026-07-04

狀態：策略發想 / 待實作（**有正式學術文獻支持**，repo 目前唯一有 peer-reviewed 依據的候選）

## 1. 核心想法

學術界記錄的 FX 日內異象：**貨幣傾向在自己的本地交易時段貶值**（相對 USD），在非本地時段回升。

```text
歐洲時段（約 03:00–11:00 NY time）→ EUR 傾向走弱 → 做空 EURUSD
美國時段（約 11:00–16:00 NY time）→ EUR 傾向走強 → 做多 EURUSD
```

成因：本地市場參與者（企業、進口商、資產管理）在自己上班時間是**外幣淨買方**（賣本幣付匯），形成系統性訂單流不平衡。這是**行為/流動性驅動**的異象，不是統計巧合。

純時間策略：**沒有任何指標、沒有任何價格條件**。參數面積趨近於零 → 過擬合風險趨近於零，這是它最大的方法論優勢。

## 2. 策略假說

- 訂單流的時段不平衡長期存在（企業付匯行為不會因為被發表就消失）。
- 在 EURUSD（點差最低的商品）上，每天固定時段持有方向部位可捕捉此漂移。
- 預期：單筆期望極小（每天幾個 pips 級別），靠高頻率（每天 2 筆）與低成本累積；**回撤特性應接近線性緩漲，而非趨勢策略的肥尾**。

## 3. 外部實證（寫想法前先查證過）

- **學術原典**：Breedon & Ranaldo (2013), *Intraday Patterns in FX Returns and Order Flow*, **Journal of Money, Credit and Banking**（[SSRN](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2099321)、[SNB working paper PDF](https://www.snb.ch/public/asset/en/www-snb-ch/publications/research/working-papers/2011/working_paper_2011_04/publications0_en/working_paper_2011_04.n.pdf)）。用高頻資料證實跨多幣種、多時區皆存在，且與訂單流方向一致。
- **獨立實作回測**：[QuantRocket — Exploiting Business Day Patterns in FX Markets](https://www.quantrocket.com/blog/business-day-fx-patterns/)：EURUSD 小時線 2005–2019，規則 = 03:00–11:00 NY 做空、11:00–16:00 NY 做多，**含真實成本（spread 0.15bp + slippage 0.1bp + commission 0.2bp）後 CAGR 6.2%、Sharpe 0.70**，跨年度表現一致。
- 判讀：效應真實但**單位時間報酬薄**。Sharpe 0.70 是「加進組合有價值」等級，不是單獨致富等級。成本假設是機構級點差 —— 零售 MT5 帳戶成本高數倍，這是本策略的主要證偽關卡。

## 4. 進場條件（機械化定義）

以 NY time 定義，實作換算 broker server time（DST 陷阱同 London Breakout 檔第 5 節）：

- **空單**：每日 03:00 NY time 開空 EURUSD，11:00 NY time 平倉。
- **多單**：每日 11:00 NY time 開多 EURUSD，16:00 NY time 平倉。
- 用 H1 收盤棒觸發（03:00 那根開盤執行），`shift=1` 慣例不適用 —— 這是定時執行，不是訊號執行；實作上在 `OnTick` 檢查 server hour 跨界即可。
- 無任何價格/指標條件。**第一版禁止加任何過濾** —— 這個策略的可貴之處就是零參數，加過濾就毀了它的方法論價值。

## 5. 過濾條件

- 只有 `MaxSpread`（異常點差時跳過當次進場）與重大假日跳過（流動性斷裂日）。
- 週五 16:00 NY 平倉後不再開新倉（本來就會如此）。

## 6. 出場與風控

- **定時出場為主**（時段結束平倉），天然無隔夜倉。
- 災難 SL：`ATR(D1) × 2` 級別的遠端保護性止損（防黑天鵝，正常日不應觸發）。
- 固定手數起步；此策略回撤結構平緩，之後才考慮波動率調整部位。

## 7. 第一輪測試計畫

1. **零參數 baseline**（這個策略沒有「調參」階段，只有「驗證」階段）：
   - 商品/週期：`EURUSD / H1`，期間 2015.01–2026.06（拉長樣本，效應是慢漂移，短樣本雜訊太大），real ticks。
   - 直接照第 4 節規則跑，無可調參數。
2. **成本敏感度是唯一重點**：以自己 broker 的真實 EURUSD 點差 + swap（雖然日內平倉無 swap）+ commission 跑；再做點差 ×1.5 / ×2 情境。**QuantRocket 的 6.2% CAGR 是 0.15bp 點差算的；若 broker 全成本 > 0.6 pip/次，預期直接死在成本上 —— 先手算損益兩平點差再決定要不要寫 EA。**
3. 年度拆分：確認 2020 後效應是否衰減（發表後 alpha decay 是真實風險）。
4. 選配延伸：同規則測 USDJPY（東京時段做多 USDJPY / 紐約時段做空）—— 論文說跨幣種成立，可當 robustness check。

## 8. 可能風險與失效條件（誠實評估）

**結論：學術等級證據 + 零參數 = 方法論上最乾淨的候選；但單位報酬薄，成敗完全取決於零售成本。**

正面：
- **唯一有 peer-reviewed 期刊論文支持**的候選，且機制（企業付匯訂單流）有明確經濟解釋。
- 零參數 → 無過擬合可能；回測結果即是效應本身的估計。
- 與 repo 所有既有策略（指標型、突破型）**相關性極低**，組合分散價值最高。
- 實作最簡單：不用任何指標，一天固定 4 個動作。

保留意見：
- **成本邊際極薄**：效應每天只有零點幾 pip 到幾 pip。機構成本下 Sharpe 0.70，零售點差（0.5–1.5 pip）可能直接吃光。**這不是「風險」，是主要死因候選。**
- **Alpha decay**：論文 2013 發表，效應廣為人知；2020 後強度需驗證。
- 持倉 8 小時中無止損保護區間內的反向大波動（新聞日：ECB、NFP 都落在持倉時段內）—— 單日尾部風險存在，靠災難 SL 兜底。
- Sharpe 0.70 意味著**會有連續數月的平/虧期**，心理上不好拿。

## 9. 進入 `Strategy_Records/` 的條件

- 以**自己 broker 真實成本**回測 2015–2026 後仍正期望（PF ≥ 1.10 即可考慮 —— 此類低波動高頻策略 PF 天花板本來就低，改看 Sharpe 與回撤形狀）。
- 2020–2026 子樣本效應仍存在（無明顯 alpha decay）。
- USDJPY robustness check 方向一致。
- 點差 ×1.5 情境下不轉負。

## 相關文件

- 決策標準與研究流程：[../Strategy_Records/MT5_Strategy_Research_Workflow.md](../Strategy_Records/MT5_Strategy_Research_Workflow.md)
- 同為時段型想法：[London_Breakout_Asian_Range.md](London_Breakout_Asian_Range.md)、[Gold_Intraday_Seasonality.md](Gold_Intraday_Seasonality.md)

## 外部參考

- [Breedon & Ranaldo (2013) — Intraday Patterns in FX Returns and Order Flow (SSRN)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2099321)
- [SNB Working Paper 2011-04 全文 PDF](https://www.snb.ch/public/asset/en/www-snb-ch/publications/research/working-papers/2011/working_paper_2011_04/publications0_en/working_paper_2011_04.n.pdf)
- [Wiley — Journal of Money, Credit and Banking 正式版](https://onlinelibrary.wiley.com/doi/abs/10.1111/jmcb.12032)
- [QuantRocket — Exploiting Business Day Patterns in FX Markets（含成本的獨立回測）](https://www.quantrocket.com/blog/business-day-fx-patterns/)

---

## 10. 實作規劃（給 Codex 的 spec）

### Phase 0：損益兩平手算（人工，不寫程式，先做）

以 QuantRocket 數據反推毛利：其淨 CAGR 6.2% 是在單邊全成本 ≈ 0.45bp（spread 0.15 + slippage 0.1 + commission 0.2）下算的；每年 2 筆/日 × ~250 日 = 500 筆，年成本 ≈ 500 × 0.45bp ≈ 2.25% → **毛利 ≈ 8.5%/年，即每筆毛 edge ≈ 1.7 pips**。

| 自己 broker 的 EURUSD 單邊全成本（spread+commission 換算） | 判定 |
|---|---|
| ≤ 0.8 pip | GO（預期淨年化 ≈ 4%+） |
| 0.8–1.2 pip | 邊緣（淨 2–4%，看能否配 ECN 帳戶） |
| ≥ 1.7 pip | KILL（數學上歸零，不寫 EA） |

Phase 0 由使用者查自己帳戶成本後定案，**未 GO 前 Codex 不動工**。

### Phase 1：定時進出引擎 EA（本檔與黃金季節性共用）

**交付物**：`Strategies/Strategy_Time_Window.mq5`（+ 編譯後 `.ex5`）

**架構**：通用「定時進出」EA，支援兩個獨立窗口（本策略用兩個；黃金策略用一個）。無指標、無訊號邏輯——只有時間、點差檢查、災難 SL。

**Inputs**（前綴 `Inp`，沿用 repo 命名慣例）：

| Input | 型別 / 預設 | 說明 |
|---|---|---|
| `InpUseWindowA` | bool / true | 窗口 A 開關 |
| `InpWindowADir` | enum BUY/SELL / SELL | 窗口 A 方向 |
| `InpWindowAOpenHour` / `Min` | int / 10, 0 | 開倉時刻（**server time**） |
| `InpWindowACloseHour` / `Min` | int / 18, 0 | 平倉時刻（server time） |
| `InpUseWindowB`、`InpWindowBDir`(BUY)、`InpWindowBOpenHour`(18)… | 同上 | 窗口 B |
| `InpFixedLots` | double / 0.01 | v1 固定手數（本策略無有意義 SL 距離，不用風險%手數） |
| `InpCatastropheATRMult` | double / 2.0 | 災難 SL = 進場價 ∓ ATR(D1,14) × mult |
| `InpMaxSpreadPts` | double / 15 | 開倉時點差上限；超過則等待，`InpSpreadWaitMin`(30) 分鐘內未回落即放棄當次並記 log |
| `InpMagic` | long / 770020 | 窗口 B 自動用 `InpMagic+1` |

**預設值換算注記**（寫進 EA 頂部註解）：規則以 NY time 定義（03:00–11:00 空、11:00–16:00 多）；EET/EEST broker（UTC+2/+3，隨歐美 DST）對 NY 的偏移常年 ≈ +7h → server 預設 10:00–18:00 空、18:00–23:00 多。歐美 DST 切換錯位的每年 2–4 週會偏移 1 小時，**v1 接受此誤差**，註解中說明。

**核心邏輯**（OnTick，不需 OnCalculate/指標 handle）：
1. 每 tick 取 server time；對每個啟用窗口維護「今日已開倉」旗標（以 server date 為鍵）。
2. 進入開倉時刻且未開倉：檢查點差 → 市價開倉（方向依 input）→ 設災難 SL（依方向量化到 tick size，沿用 `Strategy_SR_Channel_Breakout.mq5` 的方向感知量化寫法）→ 標記已開。
3. 到達平倉時刻：以 magic 找到本窗口持倉平掉；失敗（retcode 異常）下一 tick 重試並記 log。
4. 支援跨午夜窗口（close < open 視為跨日）。窗口重疊時兩窗口各自獨立持倉（magic 區分）。
5. 週五：平倉時刻照常執行；週五收盤前所有窗口強制平倉（防隔週末）。
6. **不含** OnTester 自訂評分——本策略零參數、禁止優化，不需要。

**邊界情況**：假日/斷線導致錯過開倉時刻 → 若當前時間仍在窗口內且未超過 `InpLateEntryGraceMin`（預設 60 分鐘）仍可補開，否則跳過當日；tester 起始日落在窗口中間 → 跳過該日不補。

**驗收標準**：
- MetaEditor 編譯 0 error / 0 warning。
- Tester（EURUSD H1，任一月份，real ticks）log 抽查：每日 ≤ 2 筆、進出時刻與 inputs 一致（±1 分鐘）、無隔夜週末持倉、點差放棄有 log。
- 災難 SL 存在且正常日不觸發（抽查 10 筆）。

### Phase 2：測試協定（實作完成後，由我審視回測）

- EURUSD H1，2015.01–2026.06，real ticks，初始資金 10000 USD，槓桿 1:100，固定 0.01 lot。
- 三組成本情境：broker 原始點差 / ×1.5 / ×2（tester 自訂點差）。
- 產出：年度拆分表 + 淨值曲線 + 2020–2026 子樣本獨立統計，report 命名入 `Strategy_Records/` 慣例。
- 通過標準見本檔第 9 節。
