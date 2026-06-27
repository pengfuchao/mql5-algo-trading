# PrecisionSniper + SNR Filter Strategy Idea

建立日期：2026-06-28

狀態：策略發想 / 第一優先研究方向

## 1. 核心想法

將 `PrecisionSniper` 作為主要動能訊號來源，再使用 `Support_Resistance_Channels` 作為 SNR 位置過濾器。

核心概念：

```text
PrecisionSniper 判斷是否有多空動能訊號
SNR filter 判斷該訊號出現的位置是否合理
```

這不是把 SNR 當成獨立進場訊號，而是把 SNR 當成一層交易品質過濾器。

## 2. 策略假說

`PrecisionSniper` 在 M15 短線週期會產生一定數量的動能訊號，但部分訊號出現在不佳位置：

- 做多訊號出現在壓力區附近，容易剛進場就遇到賣壓。
- 做空訊號出現在支撐區附近，容易剛進場就遇到買盤反彈。
- 價格離合理支撐/壓力位置太遠時，risk-reward 可能變差。

加入 SNR filter 後，預期可以：

1. 過濾掉靠近反向 S/R 區域的低品質訊號。
2. 提高 Expected Payoff。
3. 提高 Profit Factor。
4. 降低不必要的短線交易次數。
5. 改善 PrecisionSniper 在弱年份或盤整區間的表現。

## 3. 使用元件

### 3.1 Primary Signal

- Indicator：`Indicators/PrecisionSniper.mq5`
- EA：`Strategies/PrecisionSniperEA.mq5`
- 用途：產生主要 Long / Short 訊號。

EA 目前讀取：

```text
PrecisionSniper Buffer 3 = Buy Signal
PrecisionSniper Buffer 4 = Sell Signal
shift = 1
```

### 3.2 SNR Filter

- Indicator：`Indicators/Support_Resistance_Channels.mq5`
- 用途：提供最近支撐 / 壓力位置。

目前可用 buffer：

| Buffer | 內容 |
|---:|---|
| 2 | Resistance Broken |
| 3 | Support Broken |
| 4 | Nearest Resistance |
| 5 | Nearest Support |

本策略第一版主要使用：

```text
Buffer 4 = Nearest Resistance
Buffer 5 = Nearest Support
shift = 1
```

## 4. 第一版交易邏輯：Block-only Filter

第一版先採用較寬鬆的 block-only filter，不要求訊號一定要靠近順向 S/R，只阻擋明顯位置不佳的交易。

### 4.1 Long

當 `PrecisionSniper` 出現 Long signal：

```text
如果價格靠近最近壓力區：
    block long
否則：
    allow long
```

金融直覺：

- 靠近壓力做多，向上空間不足，容易被賣壓打回。
- 若上方壓力距離足夠，PrecisionSniper 的動能訊號才有較好的延續空間。

### 4.2 Short

當 `PrecisionSniper` 出現 Short signal：

```text
如果價格靠近最近支撐區：
    block short
否則：
    allow short
```

金融直覺：

- 靠近支撐做空，向下空間不足，容易被買盤反彈。
- 若下方支撐距離足夠，PrecisionSniper 的空方動能訊號才有較好的延續空間。

## 5. 第二版交易邏輯：Confirmation Filter

第二版再測較嚴格的 confirmation mode。

### 5.1 Long

```text
PrecisionSniper Long signal
且價格靠近 Support
且沒有太靠近 Resistance
才允許做多
```

### 5.2 Short

```text
PrecisionSniper Short signal
且價格靠近 Resistance
且沒有太靠近 Support
才允許做空
```

此模式理論上進場位置更好，但可能導致交易數過少，需特別檢查 overfitting。

## 6. 距離定義

避免使用固定 points 作為唯一距離標準，因為不同 symbol 的波動不同。第一版建議使用 ATR normalized distance。

### 6.1 定義

```text
distance_to_resistance = abs(nearest_resistance - signal_close)
distance_to_support    = abs(signal_close - nearest_support)
```

### 6.2 靠近判斷

```text
near_resistance = nearest_resistance > 0
                  and distance_to_resistance <= ATR × BlockDistanceATR

near_support    = nearest_support > 0
                  and distance_to_support <= ATR × BlockDistanceATR
```

第一輪建議測：

```text
BlockDistanceATR = 0.3, 0.5, 0.8, 1.0
```

建議起點：

```text
BlockDistanceATR = 0.5
```

## 7. 建議新增 EA Inputs

若實作在 `PrecisionSniperEA.mq5`，建議新增：

```text
InpUseSNRFilter = false
InpSNRIndicatorName = "Support_Resistance_Channels"
InpSNRMode = BLOCK_ONLY
InpSNRBlockDistanceATR = 0.5
InpSNRConfirmDistanceATR = 1.0

InpSNRPivotPeriod = 10
InpSNRSourceMode = SRC_HIGHLOW
InpSNRChannelWidthPct = 5
InpSNRMinStrength = 1
InpSNRMaxNumSR = 6
InpSNRLoopback = 290
```

預設應為關閉，避免改變現有 PrecisionSniperEA baseline。

## 8. 第一輪研究設定

優先沿用目前 PrecisionSniper 最佳短線候選。

```text
Symbol = USDJPY
Period = M15
HTF = H1
Preset = Default
MaxSpread = 15
InpUseMaxHoldingBars = true
InpMaxHoldingBars = 16
InpUseSessionFilter = true
InpSessionStartHour = 12
InpSessionEndHour = 16
Delay = 208ms / 500ms / 1000ms stress
```

SNR filter 第一輪：

```text
Mode = BLOCK_ONLY
BlockDistanceATR = 0.3, 0.5, 0.8, 1.0
```

若 block-only 有改善，再測：

```text
Mode = CONFIRMATION
ConfirmDistanceATR = 0.5, 1.0, 1.5
```

## 9. 評估指標

不能只看 Net Profit，至少比較：

| Metric | 目的 |
|---|---|
| Trades | 確認交易數是否被過度壓縮 |
| Net Profit | 初步績效 |
| Profit Factor | 勝負比品質 |
| Expected Payoff | 每筆交易是否改善 |
| Sharpe | 交易序列穩定性 |
| Max Drawdown | 風險 |
| Avg Holding Time | 是否仍符合短線目標 |
| 年度拆分 | 是否只改善特定年份 |
| Spread / delay stress | 是否可承受真實交易摩擦 |

特別關注：

```text
2021 / 2023 / 2024 是否改善
2025 / 2026 是否只是被保留下來
```

若只讓強年份更漂亮，但弱年份沒有改善，可能只是 overfit。

## 10. 主要風險

1. SNR 指標會隨新 pivot 與 rolling loopback 重算，歷史外觀不保證固定。
2. EA 必須只讀 `shift = 1` 的已收盤狀態，避免 bar 0 repaint。
3. BlockDistanceATR 若太小，filter 幾乎沒效果。
4. BlockDistanceATR 若太大，可能過濾掉太多交易。
5. Confirmation mode 可能導致交易數過少，統計意義不足。
6. SNR filter 是位置過濾，不應被當成獨立 edge。
7. 不同 symbol 的 S/R 結構差異大，USDJPY 結論不能直接外推到 XAUUSD 或 GBPUSD。

## 11. 進入正式研究紀錄的條件

若完成第一輪回測，且任一 SNR filter 設定符合以下條件，即可新增到 `Strategy_Records/PrecisionSniperEA.md`：

1. Trades 沒有下降到過低樣本。
2. Expected Payoff 明顯高於目前 USDJPY baseline。
3. Profit Factor 提升。
4. 2021 / 2023 / 2024 弱年份沒有惡化。
5. Spread / delay stress 後仍接近或維持正期望。

## 12. 當前決策

短期研究方向：

```text
優先研究 PrecisionSniper + SNR Block-only Filter
先用 USDJPY M15 / H1 HTF / Session 12-16 / MaxHoldingBars 16
確認 SNR 是否能改善位置品質與弱年份表現
```
