# 亞洲時段均值回歸（fade 假突破）策略想法

建立日期：2026-07-04

狀態：策略發想 / 待實作（先驗中低；**是 London Breakout 的鏡像策略，共用同一個 session 區間引擎**）

## 1. 核心想法

與 [London_Breakout_Asian_Range.md](London_Breakout_Asian_Range.md) 用同一個觀察，反著操作：

```text
亞洲時段（低流動性）→ 價格傾向均值回歸、突破多為假突破
→ 在亞洲時段內，價格衝出區間邊緣時「反著做」（fade），目標回到區間中軸
```

- London Breakout 賭的是「倫敦開盤後突破會延續」。
- 本策略賭的是「亞洲時段內突破不會延續」。
- 兩者共用：session 窗口管理、區間 High/Low 計算、區間品質過濾 —— **寫一次 EA 骨架，兩個假說都能測**，這是把它排進 backlog 的主因。

## 2. 策略假說

- 亞洲時段（約 00:00–07:00 London time）主要貨幣對流動性低、缺乏機構方向性訂單流，價格行為以做市商區間震盪為主。
- 此時段的區間邊緣突破缺乏後續買/賣壓，統計上傾向收回區間內。
- 進場 = 價格觸及/穿出區間邊緣後**收回區間內**（確認假突破），目標 = 區間中軸或對側，SL = 突破極值外。
- 預期：勝率偏高、單筆 RR 偏低（約 1:1 以下）的高頻小單型策略。

## 3. 外部實證（誠實：證據比其他時段型想法弱）

- **正面（機制層）**：均值回歸在亞洲時段有效是從業者間的普遍共識——低流動性使突破難以延續（[ForexTester mean reversion 指南](https://forextester.com/blog/mean-reversion-trading/)、[NewYorkCityServers Asian session 指南](https://newyorkcityservers.com/blog/asian-session-forex-strategy)）。TradingView 上有現成的 [Session Liquidity Reversion 策略腳本](https://www.tradingview.com/script/uHN2BQiV-Session-Liquidity-Reversion-Strategy-Asia-Range-False-Breakout/)，顯示此玩法在零售圈成熟。
- **反面（必須正視）**：[arXiv 2605.04004 系統性證偽研究](https://arxiv.org/pdf/2605.04004)在 MNQ（那斯達克微型期貨）上檢驗 6,442 次「liquidity grab」事件（價格刺穿 session 極值後收回），**fade 該方向的平均報酬為負，且訊號的方向性資訊量在扣除交易摩擦後不具經濟可利用性**。雖然標的是股指期貨不是 FX，但它直接打擊本策略的核心機制假設。
- 判讀：**這是本 backlog 裡證據最弱的一個** —— 正面證據全是從業者敘事，唯一的系統性研究是反面的。排進來的理由是邊際成本近零（引擎與 London Breakout 共用），不是因為先驗高。心理預期：**大概率被證偽，跑一次就結案**。

## 4. 進場條件（機械化定義）

時間以 London time 定義，換算 server time（DST 陷阱同 London Breakout 檔第 5 節）：

- **區間定義**：00:00 London time 起算的滾動區間 High/Low（前 N 根 M15，例如 N=12 → 前 3 小時），或固定用 00:00–03:00 的初始區間。第一版用固定初始區間（參數少）。
- **交易窗口**：03:00–07:00 London time（區間形成後、倫敦開盤前）。07:00 後**絕不進場** —— 倫敦開盤後假突破假設失效，這是硬邊界。
- **做空**：M15 高點穿出區間上緣 ≥ 緩衝（如 0.1 × ATR），且**收盤收回區間內** → 開空。
- **做多**：鏡像。
- **區間品質過濾**：區間高度在 `[0.15, 0.5] × ATR(D1)` 之間才交易 —— 太窄無利可圖（成本吃光），太寬代表亞洲盤已有方向性（假設不成立）。
- 每方向每日最多 1 筆。只讀已收盤棒（`shift=1`）。

## 5. 過濾條件

- `MaxSpread`（亞洲時段點差偏寬，而本策略單筆目標小 → **成本占比是全 backlog 最高**）。
- 週一凌晨跳過（週末 gap 干擾區間定義；與 [Weekend_Gap_Fade.md](Weekend_Gap_Fade.md) 的訊號日重疊，互相汙染）。
- 重大亞洲時段事件日（BoJ 決議）選配跳過，第一版不加。

## 6. 出場與風控

- TP：區間中軸（保守）或對側邊緣（激進）。第一版固定中軸。
- SL：突破極值外 `0.2 × ATR`。
- 時間出場：07:30 London time 未觸 TP/SL 一律平倉（倫敦開盤前清場，絕不把逆勢單帶進高波動時段）。
- 沿用 `MaxSpread`、Friday exit。

## 7. 第一輪測試計畫

1. **實作順序**：先寫 London Breakout 的 EA（session 區間引擎），本策略以同一 EA 加 `mode` 參數實現（BREAKOUT / FADE），不另寫程式。
2. **固定參數 baseline**：`EURUSD / M15` 與 `USDJPY / M15`（亞洲時段最有成交的兩對），2020.06–2026.06，real ticks。參數寫死：初始區間 00:00–03:00、緩衝 0.1 ATR、TP 中軸、SL 0.2 ATR、07:30 清場。
3. **成本壓測用亞洲時段真實點差**（不是全日平均），×1.5 / ×2 情境。單筆目標僅區間高度一半（可能只有 5–15 pips），**先手算：平均 TP 距離必須 ≥ 4 × 全成本才值得繼續**。
4. 對照組：同期 London Breakout（同引擎另一 mode）—— 若兩個 mode 同時賺錢或同時虧錢，檢查實作；理論上它們在同一市場狀態下應此消彼長。

## 8. 可能風險與失效條件（誠實評估）

**結論：邊際成本近零所以值得搭便車測一次，但獨立證據最弱、成本結構最差，證偽即結案，不投入第二輪。**

正面：
- 與 London Breakout 共用引擎，額外工程量 ≈ 一個 mode switch。
- 高勝率低 RR 結構與 repo 既有策略（低勝率高 RR 的突破型）回報流形狀互補。
- 時間窗口硬邊界（07:00 前）使其與 London Breakout 在時間上不重疊，可同帳戶並行。

保留意見：
- **唯一的系統性研究是反面證據**（arXiv MNQ 證偽研究），正面證據全是敘事級。
- **成本占比全 backlog 最高**：單筆目標 5–15 pips，亞洲時段點差寬，零售帳戶很可能數學上就不成立（第 7 節第 3 步的手算是第一道生死關，過不了就不用寫程式）。
- 高勝率低 RR 策略的風險形狀：平常小賺累積、偶爾一次趨勢夜（亞洲時段出大方向）把數週利潤吐光。
- 週一凌晨、重大事件夜的區間定義污染需要例外處理，例外規則本身就是過擬合面積。

## 9. 進入 `Strategy_Records/` 的條件

- 第 7 節第 3 步手算通過（TP 距離 ≥ 4 × 全成本）。
- 亞洲時段真實點差下 baseline 正期望、PF ≥ 1.15。
- 與 London Breakout mode 的相關性檢查通過（非同向同虧同賺）。
- 年度拆分中，趨勢年（如 2022）虧損可控（單年 DD 不吞掉其他年份利潤）。

## 相關文件

- 鏡像策略（共用引擎）：[London_Breakout_Asian_Range.md](London_Breakout_Asian_Range.md)
- 決策標準與研究流程：[../Strategy_Records/MT5_Strategy_Research_Workflow.md](../Strategy_Records/MT5_Strategy_Research_Workflow.md)

## 外部參考

- [arXiv 2605.04004 — OHLCV 日內訊號系統性證偽研究（含 liquidity grab fade 的反面證據）](https://arxiv.org/pdf/2605.04004)
- [TradingView — Session Liquidity Reversion Strategy（Asia Range False Breakout）](https://www.tradingview.com/script/uHN2BQiV-Session-Liquidity-Reversion-Strategy-Asia-Range-False-Breakout/)
- [ForexTester — Mean Reversion Trading 指南](https://forextester.com/blog/mean-reversion-trading/)
- [NewYorkCityServers — Asian Session Forex Strategy](https://newyorkcityservers.com/blog/asian-session-forex-strategy)

---

## 10. 實作規劃（給 Codex 的 spec）

### 前置條件（兩道關，未過不動工）

1. **手算關**：平均 TP 距離 ≥ 4 × 全成本（第 7 節第 3 步）。用 Phase 0 概算：EURUSD 亞洲盤典型區間 ≈ 15–25 pips → TP（中軸）≈ 8–12 pips；若 broker 亞洲時段全成本 > 2–3 pips 直接結案。
2. **依賴關**：`Strategy_Session_Range.mq5` 的 BREAKOUT 模式已實作並通過驗收（見 [London Breakout 檔 §10](London_Breakout_Asian_Range.md)）。本檔只是該 EA 的 **FADE 模式增量 spec**。

### FADE 模式差異 spec（相對 BREAKOUT）

**新增/改用 Inputs**（僅 `InpMode=MODE_FADE` 時生效；BREAKOUT 模式下這些參數不得影響行為）：

| Input | 預設 | 說明 |
|---|---|---|
| `InpFadeRangeEndHour/Min` | 5, 0 | 初始區間終點（≈ London 03:00；區間 = RangeStart 起 3 小時） |
| `InpFadeTradeEndHour/Min` | 9, 0 | 交易窗口終點（≈ London 07:00，**硬邊界**） |
| `InpFadeForceCloseHour/Min` | 9, 30 | ≈ London 07:30 清場 |
| `InpFadeBufferATRMult` | 0.1 | 穿出區間的最小幅度（× ATR(D1)） |
| `InpFadeSLATRMult` | 0.2 | SL = 突破極值外 × ATR(D1) |
| `InpFadeTPMode` | MIDLINE | MIDLINE（區間中軸）/ OPPOSITE（對側） |
| `InpFadeRangeMinATR` / `MaxATR` | 0.15 / 0.5 | 區間高度 ∈ [min,max] × ATR(D1) 才交易 |
| `InpSkipMondayFade` | true | 週一跳過（gap 污染區間，見第 5 節；**FADE 預設開**，與 BREAKOUT 相反） |

**觸發邏輯**（狀態機同引擎，ARMED 中每根 M15 收盤棒）：
- 做空：`high[1] ≥ rangeHigh + buffer` **且** `close[1] < rangeHigh`（穿出後收回）→ 開空。
- 做多：鏡像。
- 每方向每日最多 1 筆；同棒同時滿足多空（大振幅棒）→ 跳過並 log。
- SL = `extremum ± InpFadeSLATRMult × ATR(D1)`（extremum = 該觸發棒的 high/low）；TP 依模式；07:30 未觸即市價清場。

**與 BREAKOUT 的回歸隔離**：切換 `InpMode` 只能改變訊號邏輯與時窗，共用件（sizing、量化、點差、magic 以外）不得有模式間串擾。驗收時 BREAKOUT 參數組回歸必須逐筆一致。

### 驗收標準（FADE 增量）
- 編譯 0/0；EURUSD M15 單月抽查：所有進場都在 05:00–09:00 server 之間；09:30 後無持倉；每筆進場前一棒必有「穿出+收回」形態（人工核對 3 筆）；週一無交易。
- 與 BREAKOUT 模式對照跑同月：兩模式交易日重疊度 log 出來（理論上 FADE 觸發日多為 BREAKOUT 的 EXPIRED/虧損日）。

### 測試協定
EURUSD M15 + USDJPY M15，2020.06–2026.06 real ticks，**成本用亞洲時段真實點差**（原始 / ×1.5 / ×2）。固定參數不優化。對照實驗：同期 BREAKOUT 模式日損益相關性（見第 7 節第 4 步）。通過標準見第 9 節；**一輪定生死，不進第二輪**（第 8 節結論）。
