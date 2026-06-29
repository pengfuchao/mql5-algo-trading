# SR Channel 指標升級（Phase 2）：SBR/RBS 回測進場 (Retest)

建立日期：2026-06-29

狀態：**已驗證／否定** — 實作完成且編譯通過，但跨商品成對測試顯示 retest 在 4 商品全部 ≤ breakout（見 [Strategy_Records §S6](../Strategy_Records/Strategy_SR_Channel_Breakout.md)）。假說否定、策略結案；指標/EA 程式碼保留可用。

來源啟發：Malaysian SnR and Decision Levels [DoN] 的角色反轉（SBR/RBS）概念，見 [外部 SNR 想法彙整](SNR_External_Ideas_Harvest.md) §2-B。

## 0. 背景與動機

回測結果（見 [Strategy_Records/Strategy_SR_Channel_Breakout.md](../Strategy_Records/Strategy_SR_Channel_Breakout.md)）顯示：**裸突破訊號 edge 薄且不跨商品穩健**——EURUSD 好、USDJPY 邊際正，但 GBPUSD 虧（勝率僅 22%）、AUDUSD 打平。裸突破在愛假突破的商品上被洗。

**SBR/RBS 回測進場**用來提升訊號品質：突破發生後，被突破的通道**翻為反向角色並保留**；只有當價格**回測該翻轉位且守住**時才進場（順勢續勢）。這是過濾假突破的經典手法，目標是讓 edge 跨商品翻正。

設計沿用既有兩大不變量：**closed-bar 因果性（shift=1 已收盤棒、永不用形成中 bar0）**、**不 repaint**。但本次會引入**少量跨棒 stateful 狀態**（翻轉位清單），這是與既有「每棒重算」訊號不同之處——仍只在新棒更新、只讀已收盤棒，因此不破壞因果性。

## 1. 核心想法

```text
突破 (既有)：價格「收盤穿越通道邊緣」→ 立即順勢進場（裸突破，易假突破）
回測 (新增)：突破後記住被突破的「翻轉位」；之後價格回測該位且守住才順勢進場
            - 向上突破壓力 → 壓力翻支撐 (RBS)；回測該支撐守住 → 做多
            - 向下跌破支撐 → 支撐翻壓力 (SBR)；回測該壓力守住 → 做空
```

回測為**順勢續勢**（與既有逆勢 Bounce 方向相反，語意不同）。

## 2. 策略假說

- 突破後的回測進場勝率高於裸突破：假突破通常不會回測守住，真突破才會。
- 過濾假突破應特別改善 GBP/AUD 這類裸突破易被洗的商品 → 期望跨商品翻正。
- 回測仍是順勢，與逆勢 Bounce 互補；三類訊號（breakout / bounce / retest）可在不同 regime 各擅勝場。

## 3. 使用元件

- 指標：`Indicators/Support_Resistance_Channels.mq5`（新增 2 buffer + 翻轉位狀態機）。
- EA：`Strategies/Strategy_SR_Channel_Breakout.mq5`（新增 `SIG_RETEST` 模式）。
- ATR：指標需要 ATR 值做回測容差（ATR 相對容差才能跨商品，避免 XAUUSD vs EURUSD 尺度差異）。

## 4. 指標實作設計

### 4.1 Buffer
- `indicator_buffers 8 → 10`、`indicator_plots 8 → 10`。
- 新增 Buffer 8 = `RetestBuy`、Buffer 9 = `RetestSell`（皆 `DRAW_NONE`）。
- OnInit 補 `SetIndexBuffer(8/9,…, INDICATOR_DATA)` + `ArraySetAsSeries(...,true)` + `PlotIndexSetDouble(PLOT_EMPTY_VALUE…)` 不需要（DRAW_NONE）；firstRun 區塊補 `ArrayInitialize(...,0)`。

### 4.2 ATR handle（容差用）
- 回測容差需 ATR。現行 `handleATR` 只在 `ChannelWidthMode==WIDTH_ATR` 建立。
- 改為：**只要 retest 計算需要就建立**（即恆建立，因 retest buffer 恆計算）。Width-ATR 模式與 retest 共用同一 `handleATR`（period=`ATRLen`）。
- 對回歸無影響：Range% 寬度模式仍走 Range% 公式，多建一個 handle 只是額外計算資源。

### 4.3 翻轉位狀態機（stateful，跨棒持久）
新增全域結構陣列（上限 ~16）：
```
struct FlipLevel { double price; int dir; int age; bool active; };
// dir: +1 = 壓力翻支撐(RBS, 看多)； -1 = 支撐翻壓力(SBR, 看空)
```
於 `UpdateSignals`（每新棒、shift=1）更新：

1. **登記翻轉位**：用**原始突破**（volume gate 之前的 `rawResBroken / rawSupBroken`）登記，使 retest 獨立於 volume filter。
   - rawResBroken（向上突破壓力 top）→ push `{price=被突破 top, dir=+1}`。
   - rawSupBroken（向下跌破支撐 bottom）→ push `{price=被突破 bottom, dir=-1}`。
   - 同價位（容差內）已存在 active flip 則不重複登記。陣列滿則汰除最舊。
2. **偵測回測**（容差 `tol = RetestTolerATR * atr1`，atr1=ATR shift=1）：對每個 active flip：
   - dir=+1（看多）：`low[1] <= price + tol && close[1] > price` → `RetestBuy = close[1]`，消費(deactivate)。
   - dir=-1（看空）：`high[1] >= price - tol && close[1] < price` → `RetestSell = close[1]`，消費。
3. **失效/老化**：
   - dir=+1 若 `close[1] < price - tol`（收破翻轉位 → 翻轉失敗）→ deactivate。
   - dir=-1 若 `close[1] > price + tol` → deactivate。
   - `age++`；`age > RetestExpiryBars` → deactivate。
4. 寫 `bufRetestBuy[1] / bufRetestSell[1]`（truthy=close[1]，否則 0），index 0 歸零（比照其他訊號）。

> 因果性：登記/偵測/失效全用 shift=1 已收盤值；state 僅新棒更新、單調消費，不 repaint。firstRun 時 state 從空開始、僅處理最後一根，不回填歷史（與既有 breakout/bounce 限制相同）。

### 4.4 新增 input（接在 Phase 1 計算類 input 之後）
- `RetestTolerATR`（double，預設 0.10）：回測觸碰容差＝ATR 倍數。
- `RetestExpiryBars`（int，預設 20）：翻轉位有效期（棒數）。
- 可選顯示：`ShowRetest`（bool，預設 false）+ `DrawRetestMarker`（物件前綴沿用 `SRchan_` 開頭以利 OnDeinit 清理）。
- **iCustom 計算參數由 12 → 14**（順序：…`VolMult, RetestTolerATR, RetestExpiryBars`）。

## 5. EA 實作設計

- `ENUM_SR_SIGNAL_MODE` 新增 `SIG_RETEST = 3`（retest only）。保留 `SIG_BREAKOUT/BOUNCE/BOTH` 語意不變（零回歸）。
- `useRetest = (InpSignalMode == SIG_RETEST)`；讀 Buffer 8/9（shift=1、各自就緒檢查，失敗 return 不標記已處理）。
- 方向：`RetestBuy → buy`、`RetestSell → sell`（順勢續勢）。沿用既有 `buySig && sellSig → return` 衝突處理。
- iCustom 同步加 `InpRetestTolerATR, InpRetestExpiryBars`（鏡像順序）。
- OnInit 驗證（retest 模式啟用時）：`InpRetestTolerATR > 0`、`InpRetestExpiryBars >= 1`。
- 進場留言加 `retest`（"SRchan retest buy/sell"）以利回測歸因。
- 風控、sizing、所有 hardening 不變。

## 6. 第一輪測試計畫

1. 編譯指標 + EA → 0 error/warning。
2. **回歸**：`SIG_BREAKOUT` + 預設參數 → 交易序列與 Phase 1 後完全一致（retest buffer 恆計算但不被 breakout 模式使用）。
3. 目視：`ShowRetest=true`，確認回測箭頭出現在「突破後回測翻轉位守住」的棒；翻轉位失效/過期行為正確。
4. **核心驗證（決定策略生死）**：`SIG_RETEST` 跑 **S5 同一套跨商品**（EURUSD/GBPUSD/AUDUSD/USDJPY，XAUUSD 另議）全期 real ticks，比較 vs 裸突破：
   - 多數商品翻正、GBP/AUD 改善 → retest edge 成立，進入 walk-forward + SL/TP 最佳化。
   - 仍只有 EURUSD 賺 → SR-breakout 概念無穩健 edge，收手。
5. buffer 對齊抽查（EA 讀到的 shift=1 值與圖表標記時間一致）。

## 7. 可能風險與失效條件

1. 容差 `RetestTolerATR` 太小 → 回測訊號極少（樣本不足）；太大 → 退化成近似裸突破。需 A/B。
2. `RetestExpiryBars` 太短 → 來不及回測就過期；太長 → 過時翻轉位仍觸發。
3. 回測過濾後交易數會比裸突破更少 → 單商品樣本可能太小，跨商品合併樣本才足以判斷。
4. 翻轉位以「逐棒重算的通道邊緣」登記，邊緣會逐棒微移；以登記當下凍結 price 處理（凍結後不再隨通道移動）。
5. 仍為順勢策略，強假突破年份可能連續失敗。

## 8. 進入正式研究紀錄的條件

跨商品 retest 測試（第 6 節第 4 點）若多數商品正期望且回撤可控，於 [Strategy_Records/Strategy_SR_Channel_Breakout.md](../Strategy_Records/Strategy_SR_Channel_Breakout.md) 追加 session 紀錄並進入 walk-forward。

## 9. 不在本次範圍

- HTF confluence、proximity 過濾、強度 aging/freshness、Volume Profile（見 [外部彙整](SNR_External_Ideas_Harvest.md) §2-D/E/F/G）。
- `OnTester` 評分修正（加 PF 下限 / DD 上限懲罰）—— 獨立小任務，可併入本輪或另做。

## 相關文件

- [新增反彈訊號 (Phase 1 前身)](SRChannel_Bounce_Signal_Upgrade.md)
- [外部 SNR 指標想法彙整](SNR_External_Ideas_Harvest.md)
- [Strategy_Records：SR Channel Breakout 研究紀錄](../Strategy_Records/Strategy_SR_Channel_Breakout.md)
