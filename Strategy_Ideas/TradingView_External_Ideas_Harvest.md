# 外部 TradingView 高評價指標/策略審視（2026-07 批次）

建立日期：2026-07-04

狀態：審視完成 / A、B 待實作評估；其餘已定案（跳過或列為反面教材）

審視對象：TradingView 高 boosts / 高知名度指標與策略（僅取「方法與想法」，不照搬程式碼）。篩選標準採用 [量化策略開發框架](Quant_Strategy_Development_Framework.md) 第 5 節計分卡；harvest 定位遵循框架第 9 節——**TradingView 熱門模板是證據等級最低的想法來源，只當機制提示用**。

1. Squeeze Momentum Indicator — © LazyBear（TTM Squeeze 開源重現）
2. Chandelier Exit — ATR 追蹤止損（多個開源版本）
3. UT Bot Alerts — ATR trailing stop 翻轉觸發
4. WaveTrend Oscillator — © LazyBear
5. Machine Learning: Lorentzian Classification — © jdehorty（TradingView 2023 年度最有價值腳本）
6. Nadaraya-Watson Envelope — © LuxAlgo
7. Smart Money Concepts（order blocks / FVG / liquidity sweep）— LuxAlgo 及各家

## 0. 對照基準（repo 已覆蓋的 TradingView 資產）

避免重複收割：QQE MOD（[Vegas Tunnel 檔](Vegas_Tunnel_QQE_MOD.md)）、SuperTrend（`Indicators/ML_SuperTrend` + `testing/Supertrend.mq5`）、六支 SNR/SR 指標（[SNR harvest](SNR_External_Ideas_Harvest.md)）、SMC 參考碼（`testing/SMC_FVG_Auto_Detector.mq5`、`testing/SMC_Liquidity_Detector.mq5`，第三方代碼不動）。

## 1. 逐支審視結論

### #1 Squeeze Momentum（LazyBear / TTM Squeeze）
- 🟢🟢 **波動收縮 setup**：`BB(20,2) 完全落入 KC(20,1.5) 內 = squeeze on`；釋放（BB 重新走出 KC）常伴隨方向性擴張。**本批唯一機制有學術底的**——波動聚集（volatility clustering）是金融時序最被證實的性質之一。它不是完整策略，是框架第 3 節的 **Setup 層元件**，正好填 repo 工具箱的空格（現有過濾器沒有「波動壓縮」維度）。→ 見 §2-A。
- 🟢 **全內建可原生自算**：BB、Keltner（EMA±ATR）、momentum（linreg）都能在 EA 內用 `iBands`/`iMA`+`iATR` 或手算完成，**零 iCustom 依賴**、non-repaint、參數面積小（兩組長度倍數，基本不動）。
- ⚪ momentum 直方圖著色/斜率判向：與 QQE/MACD 同源動能，不取（方向判定交給既有策略的 trigger 層）。

### #2 Chandelier Exit
- 🟢 **ATR 追蹤止損元件**：`long stop = highest(high, n) − ATR(n) × mult`，只進不退。乾淨、non-repaint、機制透明。框架第 3 節：**出場決定回報形狀**——這是出場層的標準件。→ 見 §2-B。
- 🟡 與 repo 既有出場的重疊：Turtle 已有唐奇安追蹤、PrecisionSniper 已有 TP1/2/3 + trailing。Chandelier 是**另一種**追蹤幾何（極值減 ATR vs 通道對側），值得 A/B 但不是新機制。

### #3 UT Bot Alerts
- ⚪ **跳過（同質）**：本質 = ATR trailing stop 翻轉觸發，與 SuperTrend 同功能同源（repo 已有兩份 SuperTrend 實作）。已知問題：原版在未收盤棒上會改訊號，需 `barstate.isconfirmed` 修正——等於承認要靠 closed-bar 慣例救，repo 本來就是這麼做的。無新資訊。

### #4 WaveTrend Oscillator（LazyBear）
- ⚪ **跳過（同質）**：動能振盪器，與已在 backlog 的 QQE MOD 同功能（都是平滑動能 + 交叉訊號）。框架第 4 節規則：同功能指標互為替代品。若未來 Vegas Tunnel 檔實測時 QQE 難實作，WaveTrend 可為備胎（公式更簡單：EMA 平滑的通道位置指數），僅此而已。

### #5 ML: Lorentzian Classification（jdehorty）
- 🔴 **不採用（計分卡三紅燈）**：KNN 相似型態投票器（Lorentzian 距離 + 特徵空間近鄰）。名氣最大（2023 年度最有價值腳本），但：
  1. **機制可信度低**——「歷史相似 K 型態會重演」缺乏經濟解釋，沒有回答「誰在另一邊送錢」；
  2. **參數面積全批最大**——特徵選擇 × 鄰居數 × 多層過濾（ADX/regime/EMA），連正面評價來源都承認 curve-fitting 風險高，「buy 準 sell 不準」的使用者回饋是典型過擬合症狀；
  3. **工程成本高**——MT5 需要完整移植特徵工程 + KNN，市場上的移植版是付費黑盒，無法審計。
- 唯一可取處：它把「market regime 分類」問題擺上檯面——但 repo 用慢速 MA / ATR 水位做 regime 過濾已是同目的的低成本版。

### #6 Nadaraya-Watson Envelope（LuxAlgo）
- 🔴🔴 **反面教材（記錄在案防未來踩坑）**：病毒式流行的「完美抓頂抄底」通道，但原版用**雙邊 kernel 平滑 = 引用未來資料，天生 repaint**，歷史圖上的完美訊號是幻覺。發布者 LuxAlgo 自己聲明「無數據支持其優於傳統通道」。存在 one-sided kernel 的 non-repaint 修正版，但修正後就只是一條比較平滑的自適應均線，無獨特價值。
- **教訓入庫**：評估任何 TradingView 指標的第一個問題永遠是「畫歷史的方式和畫即時的方式一樣嗎」。QQE MOD 實作前的 buffer 驗證（Vegas 檔 §3.2）同理。

### #7 Smart Money Concepts（order blocks / FVG / liquidity sweep）
- 🟡 **只當機制提示，不開發**：`testing/` 已有兩支參考碼。三個問題：概念定義模糊（同一張圖不同作者畫出不同 order block，可證偽性差）；[arXiv 證偽研究](https://arxiv.org/pdf/2605.04004) 直接否定 liquidity grab fade 的經濟可利用性（詳見 [亞洲盤均值回歸檔](Asian_Session_Mean_Reversion.md) §3）；能機械化的部分（sweep = 假突破收回、FVG = 三棒缺口）repo 的 Bounce 訊號與 S/R 邏輯已涵蓋同義概念。

## 2. 去重後的可採用想法（依優先級）

### A.（★★★）Squeeze 狀態作為突破策略的 Setup 閘門 — 低成本高效益
- **概念**：突破訊號只在「squeeze 剛釋放」或「squeeze 持續 ≥ m 根後」才放行——低能量盤的突破（沒有波動壓縮蓄能）最容易假。
- **作法**：EA 端原生計算 `squeezeOn = (BB上軌 < KC上軌) && (BB下軌 > KC下軌)`（closed-bar），輸出布林狀態；不需要新指標、不動 iCustom 簽章。
- **掛載點**（兩個獨立實驗，勿混測）：
  1. `Strategy_SR_Channel_Breakout`（EURUSD H1 晉級線）：加 `InpUseSqueezeFilter`，突破訊號需 `squeeze 釋放後 ≤ p 根` 才進場。與量過濾（[SNR 待辦](SNR_Open_Threads.md) #1）是**正交的兩個維度**（能量蓄積 vs 參與確認），可先各自 A/B 再看疊加。
  2. London Breakout（[想法檔](London_Breakout_Asian_Range.md)）：亞洲盤區間本身就是 squeeze 的一種，可比較「區間高度過濾 vs squeeze 過濾」哪個更能挑日子——**二選一，不疊加**（同為波動收縮資訊，疊加違反框架規則三）。
- **風險**：squeeze 參數（BB/KC 長度倍數）看似固定，實測時忍住不掃——用 TTM 標準值（20/2 與 20/1.5），把自由度留給 `p`（釋放後幾根內有效）一個參數。

### B.（★★）Chandelier Exit 作為趨勢策略出場 A/B — 低成本
- **作法**：在 Turtle（正好要補 baseline）加出場模式開關：`EXIT_DONCHIAN`（現行 20 棒對側通道）vs `EXIT_CHANDELIER`（`highest(n) − ATR × mult`）。同一進場、只換出場，直接量化「出場幾何」對回報形狀的影響。
- **動機**：Turtle baseline 反正要跑（見既有評估），多一個出場 A/B 幾乎零邊際成本；結論可轉移到未來所有趨勢策略。
- **風險**：兩個新參數（n、mult）。第一輪寫死 22 / 3.0（Chandelier 慣例值），不掃。

### C.（☆ 已定案不做）UT Bot、WaveTrend、Lorentzian、Nadaraya-Watson、SMC
- 理由見 §1 各條。此節存在的目的：**未來再看到這些名字時不必重新評估**（除非出現新的系統性證據）。

## 3. 實作共通註

- A/B 兩項都是 **EA 端原生計算**，不新增指標、不碰 iCustom 參數列——這是從 SNR 案（buffer 對齊回歸成本）學到的預設偏好：**能在 EA 內算的就不要做成指標依賴**。
- Squeeze 與 Chandelier 的所有判定一律 closed-bar（`shift=1`），沿用 repo 鐵律。
- 落地前標準關卡不變：MetaEditor 0 error/warning → 加開關後 baseline 回歸（filter=off 須與原版逐筆一致）→ A/B → 年度拆分 + 成本壓測。

## 4. 建議落地順序

1. **A-1 Squeeze × SR Breakout（EURUSD H1）**：排在 SNR 待辦 #1（量過濾）與 #2（WIDTH_ATR）之後測——同一條晉級線上的第三個候選補強，三者各自 A/B 後再談組合。
2. **B Chandelier × Turtle**：與 Turtle baseline 建檔同一輪跑掉。
3. **A-2 Squeeze × London Breakout**：等 London Breakout 引擎寫好後，作為「區間品質過濾」的替代方案 A/B。

## 相關文件

- 篩選框架與計分卡：[Quant_Strategy_Development_Framework.md](Quant_Strategy_Development_Framework.md)（第 5、9 節）
- 前一批 harvest（SNR 六支）：[SNR_External_Ideas_Harvest.md](SNR_External_Ideas_Harvest.md)
- 受影響策略：[SNR_Open_Threads.md](SNR_Open_Threads.md)、[London_Breakout_Asian_Range.md](London_Breakout_Asian_Range.md)、Turtle（`Strategies/Strategy_Turtle_Trading.mq5`，待建 Strategy_Records 檔）

## 外部參考

- [LazyBear — Squeeze Momentum Indicator（TradingView）](https://www.tradingview.com/script/nqQ1DT5a-Squeeze-Momentum-Indicator-LazyBear/)
- [jdehorty — ML: Lorentzian Classification](https://www.tradingview.com/script/WhBzgfDu-Machine-Learning-Lorentzian-Classification/)、[TradeSearcher 回測彙整](https://tradesearcher.ai/strategies/2019-lorentzian-classification-strategy)、[過擬合警告（Aron Groups）](https://arongroups.co/forex-articles/lorentzian-classification/)
- [LuxAlgo — Nadaraya-Watson Envelope（含作者免責聲明）](https://www.tradingview.com/script/Iko0E2kL-Nadaraya-Watson-Envelope-LuxAlgo/)、[Python 獨立回測（Medium）](https://medium.com/@yashaswa/backtesting-the-viral-nadaraya-watson-envelop-trading-indicator-in-python-b800a70e8167)
- [Pineify — UT Bot repaint 修正說明](https://pineify.app/resources/blog/ut-bot-alerts-guide-best-settings-strategy-and-how-to-use-on-tradingview)
- [arXiv 2605.04004 — OHLCV 日內訊號證偽研究（SMC/liquidity grab 反面證據）](https://arxiv.org/pdf/2605.04004)
