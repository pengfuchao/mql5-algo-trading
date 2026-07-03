# 黃金日內季節性（亞洲盤漲 / 歐美盤跌）策略想法

建立日期：2026-07-04

狀態：策略發想 / 待實作（長期統計紀錄支持，但需先驗證近年是否仍存在）

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
