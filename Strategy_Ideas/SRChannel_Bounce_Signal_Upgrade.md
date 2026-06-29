# SR Channel 指標升級：新增反彈訊號 (Bounce / Rejection)

建立日期：2026-06-29

狀態：已實作 / 待編譯與回測驗證

## 0. 背景與動機

`Indicators/Support_Resistance_Channels.mq5` 目前只輸出**突破 (Breakout)** 訊號（壓力向上突破、支撐向下跌破），`Strategies/Strategy_SR_Channel_Breakout.mq5` 也只做順勢突破。但 S/R 指標最本命的用法是**反彈**（在支撐買、在壓力賣），而突破天然假訊號偏多。

指標其實已算好最近支撐/壓力位（buffer 4/5），卻完全未被利用。本次升級在**不改動核心通道演算法**的前提下，新增兩個與突破對稱的反彈訊號 buffer，並讓 EA 可選擇交易突破、反彈或兩者。

目標：用最低邊際成本把指標訊號能力補完整，後續一次進回測（純突破 vs 純反彈 vs 混合）。

設計沿用指標既有兩大不變量：**closed-bar 因果性（以 shift=1 已收盤棒判定、永不用形成中 bar0）**、**每根新棒才重算、不 repaint**。

## 1. 核心想法

```text
突破 (既有)：價格「收盤穿越」通道 → 順勢進場
反彈 (新增)：價格「影線觸及通道後收盤收回」→ 逆勢進場 (壓力做空 / 支撐做多)
```

兩類訊號各自獨立輸出到不同 buffer，由 EA 以 `InpSignalMode` 選擇使用哪一類或兩者。

## 2. 策略假說

- 在強支撐/壓力處的「拒絕 (rejection)」具有比突破更高的勝率，尤其在盤整 / 區間行情。
- 突破策略在趨勢年份較佳、反彈策略在盤整年份較佳，兩者可能在不同 market regime 互補。
- 反彈訊號可單獨成為一個策略變體，也可作為突破策略的反向對照組，用同一套 hardened EA 框架公平比較。

## 3. 使用元件

- Indicator：`Indicators/Support_Resistance_Channels.mq5`（本次升級對象）
- EA：`Strategies/Strategy_SR_Channel_Breakout.mq5`（本次擴充對接）
- 不新增外部依賴；ATR 止損沿用既有 `iATR`。

## 4. 進場條件

判定於 `UpdateSignals`，逐一掃描已選通道 `x ∈ [0, g_maxsr]`，`top = SR[x*2]`、`bottom = SR[x*2+1]`，`cClosed = close[1]`、`cPrev = close[2]`：

- **ResBounce（壓力拒絕 → EA 做空）：**
  `cPrev < bottom && high[1] >= bottom && cClosed < bottom`
  （上影線觸及/穿入壓力通道，但收盤收回通道下方）
- **SupBounce（支撐拒絕 → EA 做多）：**
  `cPrev > top && low[1] <= top && cClosed > top`
  （下影線觸及/穿入支撐通道，但收盤收回通道上方）

EA 方向組合（反彈為反向）：
```text
buySig  = (要突破 && ResBroken) || (要反彈 && SupBounce)
sellSig = (要突破 && SupBroken) || (要反彈 && ResBounce)
```

> 觸及一律以實際 `high[1]/low[1]`（影線）判定，與 SourceMode 無關 —— 影線拒絕正是反彈的經典型態。

## 5. 過濾條件 / 訊號互斥

**指標層天然互斥（同一通道）：**
- ResBroken 需 `close[1] > top`，ResBounce 需 `close[1] < bottom` → 不可能同時成立。
- SupBroken 需 `close[1] < bottom`，SupBounce 需 `close[1] > top` → 同上。

**EA 層衝突處理（跨通道，價格被夾在兩通道間）：**
- 沿用既有 `if(buySig && sellSig) return;`（同棒多空並現視為不明確，不交易）。無需新增邏輯。

**沿用既有過濾：** 點差過濾、broker StopsLevel/FreezeLevel、保證金檢查、方向感知交易環境檢查、Netting ownership 防護全部不變。

## 6. 出場與風控

- 本次**不變**：ATR 止損 (`InpSLMultiple`)、RR 止盈 (`InpTPRatio`)、風險% 動態手數、反向先平倉、同方向持倉上限，以及所有既有 hardening。
- 進場留言依型態微調（"SRchan breakout buy" / "SRchan bounce buy"）以利回測歸因。
- **後續項目（本次不做，僅留 hook 與註解）：** 反彈為逆勢交易，未來可加 `InpUseChannelSL`，以通道遠端邊界當 SL 取代單一 ATR 路徑。

## 7. 實作清單

### 指標 `Support_Resistance_Channels.mq5`
1. 檔頭 `indicator_buffers 6 → 8`、`indicator_plots 6 → 8`；新增兩個 `DRAW_NONE` plot：`label7 "ResBounce"`、`label8 "SupBounce"`。
2. 新增全域 `bufResBounce[]`、`bufSupBounce[]`；`OnInit` 補 `SetIndexBuffer(6/7,…)` + `ArraySetAsSeries(...,true)`；`firstRun` 區塊補 `ArrayInitialize`。
3. **`UpdateSignals` 簽章加入 `high[]`、`low[]`**（`OnCalculate` 已有，呼叫點 line 210 一併傳入），加入第 4 節判定，寫法與突破對稱（truthy=close[1]，0=無訊號，index 1 寫值、index 0 歸零）。
4. 選用：新增 `ShowBounce` input（Extras 群組，ShowBroken 之後）+ `DrawBounceMarker`；`AlertsOn` 時反彈也發 Alert。物件前綴維持 `SRchan_` 開頭以利 `OnDeinit` 清理。
5. **不新增任何計算類 input** → EA 的 `iCustom` 簽章不變。

### EA `Strategy_SR_Channel_Breakout.mq5`
1. 新增 `enum ENUM_SIGNAL_MODE { SIG_BREAKOUT, SIG_BOUNCE, SIG_BOTH }` 與 `input InpSignalMode = SIG_BREAKOUT`（預設＝完全保留現有行為，零回歸風險）。
2. `OnTick` 新增 `CopyBuffer(srHandle, 6/7, 1, 1, …)` 讀 ResBounce/SupBounce（shift=1、各自就緒檢查，任一失敗 return 不標記已處理）。
3. 依第 4 節組合 `buySig/sellSig`；衝突沿用既有 `buySig && sellSig → return`。
4. `iCustom` 與所有風控不變。

## 8. 第一輪測試計畫

1. **編譯**：MetaEditor 編譯指標與 EA，確認 0 errors / 0 warnings。
2. **指標目視**：`ShowBounce=true`，肉眼確認反彈箭頭出現在「影線觸 S/R 後收回」的 K 棒，且不與突破箭頭於同根同方向重疊。
3. **EA 回歸驗證**：`InpSignalMode=SIG_BREAKOUT` → Strategy Tester 交易序列須與升級前**完全一致**。
4. **反彈 / 混合**：`SIG_BOUNCE`（逆勢：壓力空、支撐多）與 `SIG_BOTH` 各跑一輪 visual mode，確認方向與位置正確、無同棒衝突下單。
5. **buffer 對齊抽查**：日誌比對 EA 讀到的 shift=1 值與圖表標記時間一致（排除 off-by-one / repaint）。
6. 初期商品/週期：沿用既有研究慣例（如 USDJPY，與 PrecisionSniper 研究同基準），先單一商品確認邏輯再外推。

## 9. 可能風險與失效條件

1. 通道由「逐棒重建」而非 Pine stateful，反彈位準可能逐棒微移，需確認不致使訊號抖動。
2. `ChannelWidthPct` 太寬時，影線「觸及」門檻過鬆 → 反彈訊號過多、品質下降。
3. 逆勢進場若搭配純 ATR 止損，可能止損位落在通道內、過早被掃 → 觀察是否需要通道邊界 SL。
4. 盤整假設若不成立（強趨勢年份），反彈策略可能持續逆勢虧損。
5. 不同 symbol 的 S/R 結構差異大，結論不可直接外推。

## 10. 進入正式研究紀錄的條件

完成第一輪回測後，若反彈或混合模式達成以下任一，即可在 `Strategy_Records/` 建立 SR Channel 策略研究紀錄（README 索引現為「待建立」）：

1. 樣本數足夠（Trades 不過低）。
2. Expected Payoff / Profit Factor 優於純突破 baseline，或在盤整年份明顯互補。
3. Spread / slippage stress 後仍維持正期望。

## 11. 不在本次範圍

- 通道品質升級（成交量加權、ATR 自適應寬度、通道老化淘汰）—— 第二優先，改動核心 `ComputeSR`，待反彈驗證後再做。
- Pine stateful 等價模式、多時間框架 / HTF 濾網。
- 通道邊界 SL（`InpUseChannelSL`）—— 僅留 hook 與註解。

## 相關文件

- [PrecisionSniper + SNR 位置過濾](PrecisionSniper_SNR_Filter.md)（同樣使用 Support_Resistance_Channels 作為元件）
