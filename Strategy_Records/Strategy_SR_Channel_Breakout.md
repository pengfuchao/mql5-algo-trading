# SR Channel Breakout — 研究紀錄

EA：[`Strategies/Strategy_SR_Channel_Breakout.mq5`](../Strategies/Strategy_SR_Channel_Breakout.mq5)
指標：[`Indicators/Support_Resistance_Channels.mq5`](../Indicators/Support_Resistance_Channels.mq5)
相關發想：[Phase 1/2 規劃彙整](../Strategy_Ideas/SNR_External_Ideas_Harvest.md)

建立日期：2026-06-29

狀態：**通用策略結案**（retest 否定、不跨商品穩健）；**EURUSD 專用 breakout 晉級** → 回測全關通過，已移入 [`Strategy_Live_Candidates/`](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md) 待 demo forward（詳見 §S7）。

## 1. 策略與版本

- 指標已含 Phase 1 升級：ATR 自適應通道寬度（`ChannelWidthMode`，預設 Range%）、相對 tick volume 突破確認（`UseVolumeFilter`，預設關閉）。兩者預設＝舊版行為。
- EA 訊號模式：`SIG_BREAKOUT`（順勢突破）/ `SIG_BOUNCE`（影線拒絕，逆勢）/ `SIG_BOTH`。
- 出場：ATR×`SLMultiple` 止損 + RR `TPRatio` 止盈；風險% 動態手數。

## 2. 測試環境與共用設定

- 平台：MetaQuotes-Demo（build 5958），建模 **100% 真實報價 (real ticks)**，槓桿 1:100。
- 主週期：H1。本金：tester 10,000 USD；optimization 5,000 USD。
- 報告存於本機 `Downloads`（ReportTester-SNR0x.xlsx / ReportOptimizer-SNRoptima.xml），未提交 repo。

## 3. 回測session 與結果

### S1 — 預設參數 baseline（ReportTester-SNR01）
- USDJPY H1，2020.06.26–2026.06.26。CWP=5、MaxNumSR=6、SignalMode=breakout、Range% 寬度、無量過濾。
- **結果：0 筆交易。**
- 解讀：預設 `ChannelWidthPct=5` 通道太寬、且分群會鏈接成遠大於 cwidth 的大區塊 → 通道鋪滿現價 → `inChannel` 長期 true → 突破/反彈雙雙被壓掉。
- **重要推論：升級前的 EA 用預設值同樣 0 單 → 此策略過去從未被驗證會交易；Phase 1 並未弄壞任何東西。**

### S2 — 收窄通道（ReportTester-SNR02，test B）
- USDJPY H1，全 6 年。CWP=2、MaxNumSR=3、SignalMode=both。
- 結果：~167 筆，勝率 33.5%，PF 1.23，最大回撤 ~17%，最大連續虧損 12。
- 解讀：end-to-end 管線（指標訊號→buffer→EA 下單→SL/TP）正常；但 edge 偏薄。

### S3 — 第一階段最佳化（ReportOptimizer-SNRoptima）
- USDJPY H1 全 6 年；掃 CWP 1–4、MinStrength 1–4、MaxNumSR 2–5、SignalMode 0–2；SL1.5/TP2.0 固定；criterion=Sharpe。192 passes / 48 獨立組。
- **關鍵發現：**
  1. **`ChannelWidthPct` 在 1–4 完全無效**（每組 4 個 CWP 數字完全相同）→ width 參數在此區間是 no-op（鏈接行為使其飽和）。之後最佳化可固定 CWP=2 並移除此維度。
  2. 48 組裡只有**一組**同時 PF≥1.3 且樣本充足：**breakout / MinStr=1 / MaxNumSR=3**（89 筆、PF 1.34、DD 10.6%、Recovery 1.50、Sharpe 3.39）。
  3. 高交易量組（>200 筆）幾乎都 PF 1.0–1.18、DD 30–47%（過度交易、薄邊際）。
  4. **`OnTester` 自訂評分有缺陷**：`√trades` 會把「過度交易的薄邊際」灌成高分（如 both/MinStr3/MaxSR2：Custom 74 但 PF 1.06、DD 42%）。**待修：加 PF 下限與 DD 上限懲罰。**

### S4 — 樣本外 (OOS) 驗證（ReportTester-SNR03）
- 配置：breakout / MinStr=1 / MaxNumSR=3 / CWP=2 / SL1.5 / TP2.0。
- 期間：**2024.06–2026.06（最佳化未見過的後 2 年）**。
- 結果：淨利 **+280.37（+2.8%）**、PF **1.19**、25 筆、勝率 36%、最大回撤 8.3%、Recovery 0.33、期望值 +11.21/筆。
- 解讀：**borderline 過關**。OOS 沒崩盤、仍正期望（PF>1）→ 訊號可能有一點真 edge；但樣本太小（25 筆）、邊際薄，尚不可部署。

### S5 — 跨商品穩健性（EURUSD / GBPUSD / AUDUSD / XAUUSD）
- 固定配置（同 S4），全期 2020–2026 H1，real ticks。

| 商品 | 淨利 | PF | 交易 | 勝率 | 最大回撤 | 判定 |
|---|---|---|---|---|---|---|
| EURUSD | +1,904 (+19%) | **1.49** | 67 | 38.8% | **8.0%**（Recovery 2.06）| ✅ 強 |
| USDJPY（S3 IS 參考）| +888 | 1.34 | 89 | ~ | 10.6% | ＋ |
| AUDUSD | −68 (≈0%) | 0.99 | 91 | 33% | 12.3% | ⚠️ 打平/微負 |
| GBPUSD | −2,379 (−24%) | 0.65 | 112 | 22.3% | 26.8% | ❌ 虧損 |
| XAUUSD | +11,822 (+118%) | 1.13 | 147 | 35.4% | **68.7%** | ❌ 回撤災難 |

- 解讀：**裸突破 edge 不穩健、無法泛化。** EURUSD 真的好、USDJPY 邊際正，但 GBP 虧、AUD 打平、XAU 以 68.7% 回撤換取帳面獲利（不可交易，且暴露 ATR 風險手數在高波動商品失控）。5 商品：1 強 1 微正 1 平 1 虧 1 爆 → 典型「靠少數商品過去特性擬合」。

### S6 — Phase 2 retest 跨商品驗證（決勝測試，同快照成對）
- Phase 2（SBR/RBS retest）實作完成、編譯 0 error，回歸確認乾淨（breakout buffer 程式層面未變；trade 數與 S5 的差異為 tick 資料快照漂移，跨商品系統性 ×1.5，非回歸）。
- **方法論**：S5 的舊 baseline 屬舊資料快照，不可跨快照比較。故在**同一 binary、同一份 tick 資料**上，每商品成對重跑 breakout 與 retest。期間/設定同 S5（H1 2020.06–2026.06、real ticks、CWP=2、MinStr=1、MaxSR=3、SL1.5/TP2.0、RetestTolerATR=0.10、RetestExpiryBars=20）。

| 商品 | Breakout PF / 淨利 / 筆 / 勝率 | Retest PF / 淨利 / 筆 / 勝率 | 結果 |
|---|---|---|---|
| EURUSD | 1.47 / +2573 / 103 / 35.0% | 1.41 / +1957 / 83 / 38.6% | ❌ 變差 |
| USDJPY | 1.30 / +2134 / 133 / 34.6% | 1.12 / +783 / 106 / 34.9% | ❌ 明顯變差 |
| AUDUSD | 0.92 / −591 / 136 / 27.9% | 0.90 / −699 / 112 / 29.5% | ❌ 略差（仍負）|
| GBPUSD | 0.70 / −2815 / 187 / 19.3% | 0.64 / −3160 / 147 / 21.8% | ❌ 更差 |

- **判讀：retest 在 4 個商品全部 ≤ breakout。** 未救起 GBP/AUD（仍負、且更負），並砍掉 EUR/JPY 的獲利。
- **機制**：retest 只把交易數砍 ~20%（非強過濾）——預設 `RetestTolerATR=0.10` + 寬鬆觸碰條件使 retest 在突破後緊接一兩根即觸發。被砍掉的 20% 多為「突破後頭也不回的 runaway 贏單」，留下在關卡來回磨的弱單 → 反而更差。這是回測進場的結構代價（系統性錯過最強續勢單），非 bug。

### S7 — EURUSD 專用 breakout：walk-forward + 成本壓測（通過，已晉級）
固定配置：EURUSD H1、`SIG_BREAKOUT`、CWP=2、MinStr=1、MaxSR=3、SL1.5、TP2.0、Risk 1%。

1. **參數 walk-forward（內建 Forward 1/3，criterion=Sharpe，genetic，open prices）**：
   - 最佳區 **MinStr=1 / MaxSR=3** 在 IS（Back）與 Forward **兩段都贏、且不挑 SL/TP** → 穩定高原、非單點擬合。
   - IS 最佳組 Forward 仍正（Forward PF 1.46、+1007、DD 5.56%）。
2. **逐年穩定性（固定配置、real ticks、6 個年窗）**：

| 年窗 | 交易 | 淨利 |
|---|---|---|
| 2020–21 | 1（幾乎未進場，忽略）| +196 |
| 2021–22 | 13 | +73 |
| 2022–23 | 17 | +261 |
| 2023–24 | 22 | +365 |
| 2024–25 | 29 | +1009 |
| 2025–26 | 15 | +458 |
| 合計 | ~97 | +2362 |

   - **6/6 年正、無虧損年**；拿掉最強的 2024–25 後其餘 5 年仍合計 +1353，**非單年撐起**。勝率穩定 ~30–40%（靠賠率）。
3. **成本壓測（commission $3.5/手/單邊＝來回 $7/手，real ticks 全期）**：
   - **PF 1.42、淨利 +2180**（對照無成本 baseline PF 1.47 / +2573）→ **影響小、edge 維持**。

- **結論：EURUSD 專用 breakout 通過全部回測關卡（全期 + Forward + 高原 + 逐年 + 成本）→ 晉級 demo forward。**
- 部署卡（寫死最優設置）：[Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md)。

### S8 — 第二階段優化前置：修正 `OnTester` 評分

- 目的：S3 發現舊版 `recovery × PF × √trades` 會偏好「交易很多但 PF 薄、DD 高」的組合，不適合作為後續 `UseVolumeFilter` / `WIDTH_ATR` optimization 排序依據。
- 變更：`Strategy_SR_Channel_Breakout.mq5` 新增 optimization inputs：
  - `InpOptMinTrades`
  - `InpOptMinProfitFactor`
  - `InpOptMaxDDPercent`
  - `InpOptTradeBoostCap`
- 新評分邏輯：先排除交易數不足、非正報酬、PF 低於門檻、DD 超過上限的 pass；通過後用 `recovery × PF edge × capped sqrt(trades) × DD penalty` 排序。
- 注意：本節只是**優化目標函數修正**，尚未代表任何新策略結果。下一步才是同快照 A/B 測試 `UseVolumeFilter` 與 `WIDTH_ATR`。
- 補充診斷：`VolMult=10` 極端測試發現 EA input 正確，但指標實例收到的 `VolMaLen/VolMult` 發生右移（例如 20/10 被讀成 10/0.10），屬 `iCustom` 參數對齊風險。為避免 volume filter 研究被指標 input ordering 汙染，`InpUseVolumeFilter` 改由 EA 端以 `CopyTickVolume` 對 breakout 訊號直接 gate；指標端 volume filter 保留但 EA 不再依賴它。
- `WIDTH_ATR` 測試前置修正：因 `InpATRMult` optimization 也出現各 pass 結果完全相同，agent log 證實 EA 端有傳 `WidthMode=1 / ATRLen=14 / ATRMult=0.2~0.8`，但 indicator 實際收到 `ChannelWidthMode=14 / ATRLen=1 / ATRMult=0.0100`。因此 S/R 計算參數不再依賴 custom-indicator positional inputs；EA 改在建立 handle 前用 tester-local Global Variables 寫入 effective settings，indicator `OnInit()` 讀取 override 後再計算 channel。

#### S8 下一輪測試矩陣（已跑，見 S9）

固定 baseline：EURUSD H1、2020.06.26–2026.06.26、real ticks、`SIG_BREAKOUT`、CWP=2、MinStr=1、MaxSR=3、Loopback=290、Range%、`UseVolumeFilter=false`、SL1.5、TP2.0、Risk 1%。

1. **Volume filter A/B**
   - 固定 Range% channel。
   - `UseVolumeFilter=true`
   - 掃：`VolMaLen=20`，`VolMult=1.0 / 1.2 / 1.5`
2. **ATR channel width A/B**
   - 固定 `UseVolumeFilter=false`。
   - `ChannelWidthMode=WIDTH_ATR`
   - 掃：`ATRLen=14`，`ATRMult=0.2 / 0.3 / 0.5 / 0.8`
3. **Combined test**
   - 只有當 #1 或 #2 單獨改善時才跑。
   - 用最佳 volume setting × 最佳 ATR-width setting 做小型交叉，不做大網格。

Pass 條件：同一 tick 快照下，PF 不低於 baseline、DD 不高於 baseline、交易數不低於 50，且成本壓測後仍維持正期望。若只改善 IS、不改善 Forward/OOS，視為 data mining，不晉級。

### S9 — Phase 1 filters A/B：Volume filter 與 `WIDTH_ATR` 否定

#### S9.1 — 為什麼一開始 optimizer 結果都一樣

- 症狀：
  - `InpUseVolumeFilter=true` 且 `InpVolMult=10` 時，交易數一開始完全沒有變，表示 volume gate 實際沒有套到 breakout。
  - `InpChannelWidthMode=WIDTH_ATR` 後只優化 `InpATRMult`，各 pass 一開始也出現結果完全相同，表示 ATR width 參數沒有真正進入 indicator channel 計算。
- 不是單純 tester 設定問題：其中一次確實有 MT5 optimization cache 造成 `optimization already processed / reading from cache`，但清 cache/改日期後重新跑仍需要檢查 agent log。
- root cause：custom indicator positional inputs 在 Strategy Tester / local agent 實際載入時發生參數對齊錯位。
  - Volume 診斷：EA log 顯示 `VolMaLen=20 / VolMult=10.00`，但 indicator log 顯示 `VolMaLen=10 / VolMult=0.10`。
  - ATR 診斷：EA log 顯示 `WidthMode=1 / ATRLen=14 / ATRMult=0.2~0.8`，但 indicator log 顯示 `ChannelWidthMode=14 / ATRLen=1 / ATRMult=0.0100 / ChannelWidthPct=1`。
- 修正：
  1. `InpUseVolumeFilter` 改由 EA 端以 `CopyTickVolume` 對已收盤 breakout 訊號直接 gate，避免 indicator-side volume input 錯位。
  2. S/R channel 計算參數不再依賴 custom-indicator positional inputs；EA 在建立 indicator handle 前用 tester-local Global Variables 寫入 effective settings，indicator `OnInit()` 讀取 override 後再計算 channel。
  3. 新增 agent-log 診斷：`SR Channel override params`、`SRchannel EA override applied`、`SRchannel width inputs`。
- 修正後確認：agent log 已顯示 `ChannelWidthMode=1 / ATRLen=14 / ATRMult=... / ChannelWidthPct=2`，且 optimizer 不同 `ATRMult` pass 已產生不同結果；因此後續結果可視為 `WIDTH_ATR` 真正生效後的測試。

#### S9.2 — Volume filter A/B 結果

固定：EURUSD H1、2020.06.26–2026.06.26、real ticks、`SIG_BREAKOUT`、Range%、CWP=2、MinStr=1、MaxSR=3、Loopback=290、SL1.5、TP2.0、Risk 1%。

| VolMult | Profit | PF | Expected Payoff | Recovery | Sharpe | Equity DD % | Trades | 判讀 |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1.0 | 2375.89 | 1.583 | 34.43 | 3.41 | 6.61 | 5.47 | 69 | trade quality 改善，但總報酬/Recovery 不及 baseline |
| 1.2 | 2530.72 | 1.709 | 42.18 | 3.08 | 7.83 | 6.30 | 60 | IS 最佳候選，但 DD 較高 |
| 1.4 | 2138.94 | 1.746 | 42.78 | 3.34 | 7.68 | 5.50 | 50 | PF 高但交易數低、總報酬下降 |
| 1.6 | 1047.61 | 1.470 | 27.57 | 1.52 | 5.46 | 6.27 | 38 | 樣本過少，改善不足 |

Back/Front 驗證：

| 設定 | Back PF / Profit / Trades | Front PF / Profit / Trades | 判讀 |
|---|---|---|---|
| `VolMult=1.2` | 2.143 / +1799 / 32 | 1.367 / +618 / 28 | forward 弱化，trades < 30 |
| `VolMult=1.4` | 2.158 / +1571 / 28 | 1.388 / +505 / 22 | forward 弱化且樣本更少 |

結論：volume filter 技術上已生效，且 IS 會提高 PF/Expected Payoff；但 forward robustness 不足、交易數偏少、Recovery/DD 沒有優於 baseline。**不替代 EURUSD live-candidate baseline**。

#### S9.3 — `WIDTH_ATR` A/B 結果

固定：EURUSD H1、2020.06.26–2026.06.25、real ticks、`SIG_BREAKOUT`、`InpChannelWidthMode=WIDTH_ATR`、`InpUseVolumeFilter=false`、CWP=2、MinStr=1、MaxSR=3、Loopback=290、SL1.5、TP2.0、Risk 1%。

第一輪 `ATRMult=0.2~0.8`：

| ATRMult | Profit | PF | Expected Payoff | Equity DD % | Trades |
|---:|---:|---:|---:|---:|---:|
| 0.2 | -5841.28 | 0.927 | -2.46 | 71.97 | 2377 |
| 0.3 | -5208.41 | 0.934 | -2.34 | 63.19 | 2228 |
| 0.4 | -2420.66 | 0.975 | -1.14 | 46.56 | 2120 |
| 0.5 | -5194.30 | 0.925 | -2.55 | 62.54 | 2036 |
| 0.6 | -3906.90 | 0.957 | -1.91 | 57.96 | 2049 |
| 0.7 | -3332.39 | 0.968 | -1.62 | 54.07 | 2054 |
| 0.8 | -5372.04 | 0.931 | -2.62 | 61.91 | 2054 |

第二輪 `ATRMult=1.0~5.0`：

| ATRMult | Profit | PF | Expected Payoff | Equity DD % | Trades |
|---:|---:|---:|---:|---:|---:|
| 1.0 | -5874.74 | 0.926 | -2.87 | 61.11 | 2047 |
| 1.5 | -6015.88 | 0.935 | -2.93 | 73.73 | 2052 |
| 2.0 | -5560.34 | 0.942 | -2.80 | 72.03 | 1987 |
| 2.5 | -7457.66 | 0.894 | -3.87 | 81.24 | 1929 |
| 3.0 | -5611.86 | 0.919 | -2.95 | 65.75 | 1905 |
| 3.5 | -7069.02 | 0.872 | -3.94 | 73.63 | 1793 |
| 4.0 | -4820.61 | 0.932 | -2.87 | 53.53 | 1680 |
| 4.5 | -5848.21 | 0.920 | -3.66 | 69.13 | 1597 |
| 5.0 | -3653.33 | 0.941 | -2.50 | 60.34 | 1464 |

結論：`WIDTH_ATR` 讓交易數從 baseline 約 103 筆暴增到 1464–2377 筆，PF 全部 < 1、DD 46%–81%。這不是可優化高原，而是 channel geometry 被改成大量 false breakout。**`WIDTH_ATR` 在目前 EURUSD H1 breakout 架構下否定，不做 Back/Front。**

### S10 — `iCustom` 參數錯位：S1–S9 全部作廢與真實參數的還原（2026-07-21）

**起因**：為了做出場端 breakeven A/B，重跑 EURUSD baseline 作為對照組，得到 2088 筆、PF 0.999——與紀錄中的 103 筆、PF 1.47 相差 20 倍。

#### 10.1 排除過程

| Run | 組合 | 交易數 | PF | 用途 |
|---|---|---:|---:|---|
| A | HEAD build，CWP=2/MaxSR=3 | 2088 | 0.999 | 排除 breakeven 改動（結果與含 breakeven 版本相同）|
| B | `26e0f6a` build，同參數 | **103** | **1.466** | 精確重現 S7 數據 |
| C | HEAD build，CWP=5/MaxSR=6 | 3639 | 0.906 | 排除「參數標錯」假說（沒有任何參數組合能在 HEAD 上得到 103）|

訊號層級比對（`Utilities/SRChannel_Signal_Diff.mq5`，在 tester 中並排跑兩個世代的指標）：

- HEAD：2631 根 K 棒有突破訊號（7.05%）
- `26e0f6a`：108 根（0.29%）
- 第一根分歧：2020.06.09 10:00

同時以 positional 與 override 兩種方式建立 HEAD 指標，兩者訊號**完全相同**（逐根、逐 buffer 值），排除傳參機制本身。

#### 10.2 根因

**`input group` 會佔用一個 `iCustom` positional 參數位。**

`Support_Resistance_Channels.mq5` 的第一個宣告是 `input group "Settings"`，位於 `PivotPeriod` 之前。EA 以 positional 方式傳入 14 個參數時，第一個值被 group 吃掉，其餘**整體前移一位**，最後一個參數收不到值而保留預設。無編譯錯誤、無執行期錯誤。

實測（指標端 `EFFECTIVE` 傾印 vs EA 請求值）：

| 指標 input | EA 請求 | 指標實收 | 來源 |
|---|---|---|---|
| PivotPeriod | 10 | **4**（0 夾限）| 空 |
| SourceMode | High/Low (0) | **2 → Close/Open 分支** | ← ChannelWidthPct |
| ChannelWidthPct | 2 | **1** | ← MinStrength |
| MinStrength | 1 | **3** | ← MaxNumSR |
| MaxNumSR | 3 | **10**（290 夾限）| ← Loopback |
| Loopback | 290 | **100**（0 夾限）| ← ChannelWidthMode |
| ChannelWidthMode | Range% (0) | 14 → 非 ATR，仍走 Range% | ← ATRLen |
| UseVolumeFilter | false | **true**（VolMaLen=1, VolMult=0.1，門檻近乎無效）| ← VolMaLen |
| RetestExpiryBars | 20 | 20（預設，無值可收）| — |

**commit `65062e9`（2026-07-02）意外修好了這個 bug**：它改用 global variable override，在 positional 之後覆寫，把錯位的值全部蓋掉。該 commit 被記為 hardening，而修好後交易數 103 → 2088 的巨變因為沒有重跑 baseline 而未被察覺，其後三週的研究都建立在斷層上。

#### 10.3 真實參數還原（決定性驗證）

以**修正後的程式碼**刻意設定成當年實際生效的那組參數重跑：

`PivotPeriod=4`、`SourceMode=Close/Open`、`ChannelWidthPct=1`、`MinStrength=3`、`MaxNumSR=10`、`Loopback=100`（其餘同部署卡：Breakout、Range%、SL 1.5、TP 2.0、Risk 1%）

| | S7（錯位參數，舊 build）| S10（刻意設定，修正後 build）|
|---|---:|---:|
| 交易數 | 103 | **103** |
| PF | 1.466 | **1.466** |
| 毛利 | 8093.02 | **8093.02** |
| 淨利 | +2573 | **+2572.71** |

毛損差 0.64 USD，來自指標端 volume filter 的近似（當年錯位成 `true` 但門檻為前一根量的 0.1 倍，實質 no-op；現行 EA 硬寫為關閉）。

**結論：edge 是真的，但它屬於上述參數組，與部署卡 §2 記載的參數無關。**

#### 10.4 作廢範圍

- **S1–S7 全部作廢**：皆跑在錯位參數上。其名目參數（CWP、MaxSR、Loopback、Source）與實際生效值無對應關係。
- **S8**（`OnTester` 評分修正）不受影響：純評分函式，不經 `iCustom`。
- **S9 需重測**：跑在修正後的程式碼上，但對照的 baseline 是 S7 的舊數字，實驗組與對照組跨世代，結論不成立。`UseVolumeFilter` 與 `WIDTH_ATR` 退回待測。
- **§6「`ChannelWidthPct` 在 1–4 無效」作廢**：該觀察來自 S3，當時 `ChannelWidthPct` 收到的是 `MinStrength` 的值，掃描 CWP 1–4 實際上在掃描一個不存在的維度。
- **`PrecisionSniperEA` 核心不受影響**（`PrecisionSniper` 指標無 `input group`）；僅 `InpUseSNRFilter=true` 時會踩到，該 filter 預設關閉且已 shelved。任何開啟該 filter 的實驗需作廢。

#### 10.5 已建立的防護

- 指標 `OnInit` 傾印全部 14 個生效參數（`SRchannel EFFECTIVE:`），與 EA 的請求值可逐項對照。
- `AGENTS.md` 規則 8a/8b：禁止對含 `input group` 的指標使用 positional `iCustom`；EA 與指標雙方都必須記錄參數，且交易數為介面改動的 canary。
- `Utilities/SRChannel_Signal_Diff.mq5` 保留為回歸工具。

## 4. 結論

> ⚠️ 以下 S1–S7 相關結論**已於 S10 作廢**，保留供追溯。有效結論見 S10。

- ~~**通用策略結案**：Phase 2 retest 假說否定、SR-channel 突破/回測無跨商品穩健 edge。~~ 跨商品測試（S5）跑在錯位參數上，需重測。
- ~~**EURUSD 專用 breakout 晉級**~~：晉級依據的參數表與績效不對應，部署卡已標記停用。
- Phase 1 filter/width 結論（S9）：退回待測，理由見 10.4。
- **S10 有效結論**：EURUSD H1 breakout 在 `prd=4 / Close-Open / CWP=1 / MinStr=3 / MaxSR=10 / Loopback=100` 這組參數上，六年 103 筆、PF 1.466、淨利 +2573。**此為單次全期 in-sample 結果，尚未經任何樣本外或穩健性檢驗。**

## 5. 後續

1. **EURUSD 線從 S1 重跑全部關卡**，以 10.3 的參數組為 baseline：全期 → walk-forward（內建 Forward）→ 逐年穩定性 → 跨商品 → 成本壓測。原本的 S3–S7 檢驗名義上測的是另一組參數，不可沿用。
2. **重跑前先確認 `SRchannel EFFECTIVE:` 與 EA 請求值一致**，並記錄交易數作為後續介面改動的 canary。
3. S9 的 `UseVolumeFilter` / `WIDTH_ATR` 在新 baseline 上重測。
4. 出場端 breakeven A/B（原本的 S10 計畫）延後至新 baseline 確立之後。

## 6. 已知無效 / 注意事項

- ~~`ChannelWidthPct` 在 1–4 對結果無效（鏈接飽和）~~ **已於 S10 作廢**：該觀察是參數錯位的產物。
- `WIDTH_ATR` 在 EURUSD H1 breakout 造成交易數暴增與 PF<1（S9）——**需在新 baseline 上重測**。
- 高波動商品（XAUUSD）的 ATR 風險手數會放大回撤，需另行檢視風控。
- 所有結果皆為 in-sample 或單次 OOS，**非 live readiness**；尚未納入 commission/swap、broker 差異與多 regime 壓力。
- **`input group` + positional `iCustom` 會造成沉默的參數錯位**（S10）。任何新增的 EA↔指標介面都必須雙向記錄參數後才可信任回測結果。

## 6.5 重驗序列 R1–R6（2026-07-21 建立，**門檻於執行前寫定**）

S1–S7 作廢後，本線以 S10.3 還原出的參數組從頭重驗。**本節的判定門檻在任何 R2+ 結果產出之前寫定，不得於見到結果後調整。**

### 共用設定（每一關都相同）

| 項目 | 值 |
|---|---|
| EA / 指標 | `Strategy_SR_Channel_Breakout` / `Support_Resistance_Channels` |
| 商品 / 週期 | EURUSD / H1（R5 除外）|
| 模型 | Every tick based on real ticks |
| 初始資金 / 槓桿 | 10,000 USD / 1:100 |

**參數組（S10.3 還原值，R1–R3、R5–R6 全程固定不動）**

| Input | 值 | | Input | 值 |
|---|---|---|---|---|
| `InpPivotPeriod` | **4** | | `InpSignalMode` | Breakout (0) |
| `InpSourceMode` | **Close/Open (1)** | | `InpChannelWidthMode` | Range% (0) |
| `InpChannelWidthPct` | **1** | | `InpSLMultiple` | 1.5 |
| `InpMinStrength` | **3** | | `InpTPRatio` | 2.0 |
| `InpMaxNumSR` | **10** | | `InpUseRiskSizing` | true |
| `InpLoopback` | **100** | | `InpRiskPercent` | 1.0 |
| `InpUseVolumeFilter` | false | | `InpMagic` | 770010 |

### 每一關的強制前置檢查

1. Journal 出現 `SRchannel EFFECTIVE:`，且 `PivotPeriod=4 Source=1 ChannelWidthPct=1 MinStrength=3 MaxNumSR=10 Loopback=100` 逐項相符。**不符即中止，不看績效數字。**
2. 記錄交易數。交易數是介面改動的 canary（S10 教訓）。

### 關卡與門檻

| 關 | 內容 | 通過門檻（事前寫定）|
|---|---|---|
| **R1** | 全期 2020.06–2026.06，固定參數 | ✅ **已完成**（S10.3）：103 筆、PF 1.466、+2572.71 |
| **R2** | **樣本外分割**：Development 2020.06–2024.06 / OOS 2024.06–2026.06，**參數固定、不最佳化** | OOS `PF ≥ 1.20` **且** OOS 交易數 `≥ 30`。OOS `PF < 1.0` → 直接結案 |
| **R3** | **逐年穩定性**：6 個一年窗，參數固定 | `≥ 5/6` 年淨利為正，**且**扣除最佳年後其餘年合計仍為正 |
| **R4** | **參數敏感度（本線最關鍵）**：對 `PivotPeriod {3,4,5}`、`ChannelWidthPct {1,2}`、`MinStrength {2,3,4}`、`Loopback {100,150}` 逐一單軸微調，其餘固定 | 鄰點中 `≥ 50%` 維持 `PF ≥ 1.20`。若僅原點高、鄰點全面崩壞 → 判定為尖峰而非高原，**結案** |
| **R5** | **跨商品**：GBPUSD / AUDUSD / USDJPY / XAUUSD，參數固定 | **不設否決門檻**（本線本即單商品候選）。僅記錄，用於判斷 edge 性質 |
| **R6** | **成本壓測**：commission $3.5/手/單邊（來回 $7），全期 | 成本後 `PF ≥ 1.20`，且每筆 edge / 成本地板比值 `≥ 3`（見 [workflow Step 0.5](MT5_Strategy_Research_Workflow.md)）|

### 執行順序與提前中止

**R2 → R3 → R4 → R6 → R5**（R5 純記錄，放最後）。

任一關未達門檻即**停止後續關卡**並結案，不得以「再調一下參數看看」延續——那正是把隨機參數變成過度擬合的路徑。

### 本序列的特殊性

S10.3 的參數組是**由 bug 隨機產生、未經任何最佳化挑選**。這有兩面：

- **有利**：它沒有被 in-sample 挑選過程污染，103 筆、6/6 年正不是挑櫻桃的結果。
- **不利**：它同樣沒有被任何穩健性篩選過，落在尖峰上的機率不低。

因此 **R4 參數敏感度是本序列資訊量最高的一關**，重要性高於一般流程中的位置。若鄰點全面崩壞，即使 R2/R3 通過，本線仍應結案。

## 7. 附錄：EA 行為與介面文件（2026-07-04 自 `Strategies/README.md` 移入，行為文件以本節為準）

*   **功能**: 支撐/壓力通道 EA，可交易順勢突破、支撐/壓力反彈、SBR/RBS 回測進場，或突破+反彈混合。
*   **訊號來源**: 透過 `iCustom` 對接 `Indicators/Support_Resistance_Channels.mq5`，讀取已收盤 K 棒 (`shift = 1`) 的 Buffer `2` (Resistance Broken)、Buffer `3` (Support Broken)、Buffer `6` (Resistance Bounce)、Buffer `7` (Support Bounce)、Buffer `8` (Retest Buy) 與 Buffer `9` (Retest Sell)。EA 在建立 handle 前會用 tester-local Global Variables 寫入 S/R effective settings，indicator `OnInit()` 讀取後覆蓋 `PivotPeriod, Source, ChannelWidthPct, MinStrength, MaxNumSR, Loopback, ChannelWidthMode, ATRLen, ATRMult, UseVolumeFilter, VolMaLen, VolMult, RetestTolerATR, RetestExpiryBars`，避免 MT5 custom-indicator positional input 對齊差異污染測試。使用前必須確認指標已編譯且路徑 (`InpIndicatorName`) 正確。
*   **進場與過濾**: `InpSignalMode=SIG_BREAKOUT` 時維持舊版邏輯：壓力向上突破 → 做多、支撐向下跌破 → 做空。`SIG_BOUNCE` 時改用反彈邏輯：支撐拒絕 → 做多、壓力拒絕 → 做空。`SIG_BOTH` 同時接受突破與反彈兩類訊號。`SIG_RETEST` 只交易順勢 SBR/RBS 回測：Retest Buy → 做多、Retest Sell → 做空。若同一根已收盤 K 棒同時出現多空訊號，視為不明確並跳過。`InpUseVolumeFilter` 於 **EA 端** 對 breakout 訊號做相對 tick-volume gate，避免 `iCustom` 指標參數順序差異造成 filter 未生效；`InpChannelWidthMode=WIDTH_ATR` 仍會改變上游 channel 幾何。兩者預設皆保留舊版 breakout 行為。EA 僅在新 K 棒評估，並以最大點差過濾。可選同方向僅持一張 (`InpOnePosition`) 或限制同方向最大持倉數 (`InpMaxPositions`)；反向訊號先平倉，且**確認反向倉全部關閉後才允許新進場** (避免平倉失敗造成多空對鎖/淨倉錯誤)。下單前以方向感知方式檢查 symbol trade mode (Buy 拒 `SHORTONLY`、Sell 拒 `LONGONLY`，並拒 `DISABLED`/`CLOSEONLY`) 與 terminal/account 權限。
*   **帳戶 ownership (Netting vs Hedging)**: Hedging 帳戶以 symbol + MagicNumber 管理各自部位。**Netting/Exchange 帳戶下，若該 symbol 已存在「非本 EA MagicNumber」的部位 (其他策略或人工單)，EA 一律禁止新進場並記錄原因**，絕不關閉、修改或反轉非本 EA 的 exposure；無法判定 ownership 時 fail closed。
*   **倉位與止損**: 止損採 ATR × 倍數，下限納入 `max(StopsLevel, FreezeLevel) + spread`；止盈以 RR 比例設定並套 broker 最低距離。**SL/TP 依方向量化** (Buy SL 向下、Buy TP 向上、Sell SL 向上、Sell TP 向下對齊 `SYMBOL_TRADE_TICK_SIZE`)，量化後重新驗證真實距離，不符即不下單。手數依淨值風險% 與「量化後真實 SL 距離」計算；**risk 模式下任一必要資料 (tick value/size、equity、SL 距離) 無效一律 fail closed (不回退固定手數)；最小手數實際風險超過上限、或 `InpRiskPercent<=0` 時略過進場而非放大手數**。`OnInit` 對無效 inputs (風險/固定手數<=0、ATRPeriod<1、SLMultiple<=0、TPRatio<0、MaxPositions<1) 回傳 `INIT_PARAMETERS_INCORRECT`。
*   **掛載與同步**: 預設等待下一根新 K 棒才交易，避免掛載/重編譯當下吃上一根 stale signal (`InpTradeOnFirstBar=true` 可改為立即)。新 K 棒**僅在指標/ATR buffer (`BarsCalculated` + `CopyBuffer`) 成功讀取後才標記為已處理**；暫時讀取失敗會留待同根後續 tick 重試，避免永久漏訊號，同時保證同一根 K 棒不重複下單。保證金以 `OrderCalcMargin` 預檢，無法計算時 fail closed；下單後記錄 retcode/deal/order 並區分 deal completed / accepted / 失敗。
*   **回測與優化**: 內建 `OnTester()` 自訂適應度，先以 `InpOptMinTrades`、`InpOptMinProfitFactor`、`InpOptMaxDDPercent` 排除樣本不足、PF 過低或 DD 過高的 pass，再以 `recovery × PF edge × capped sqrt(trades) × DD penalty` 排序；`InpOptTradeBoostCap` 用來限制交易數 boost，避免最佳化偏向過度交易但 edge 很薄的組合。此 criterion 僅供 Strategy Tester optimization 排序，不代表 live readiness。
*   **使用限制**: 上游指標為 **repaint** 且**與 TradingView 非 signal-identical** (通道每根重算、已收盤棒判定)，EA 僅信賴已收盤棒 (`shift=1`) 訊號，但回測與實盤行為仍可能因通道重算而不同。Bounce/rejection 屬逆勢訊號，需特別檢查強趨勢年份、交易成本、停損是否過早落在通道內，以及與 breakout regime 的互補性。Retest 交易數通常會少於裸突破，需跨商品合併樣本判斷是否真的改善假突破。FX volume filter 使用相對 tick volume，不是真實成交量；ATR channel width 是 mode switch，會影響所有下游訊號，不能與 Range% baseline 直接視為同一策略。**未實作自訂交易時段 (session) 排程**：收盤/非交易時段的下單由 broker 端拒絕並記錄 (跨午夜/多段 session 的精確排程未納入)。需自行於 Strategy Tester 納入 spread、commission、slippage 與多種市場狀態驗證。**反向平倉失敗防護與 Netting ownership 防護在回測中不易觸發 (tester 平倉幾乎必成、單帳戶單策略)，務必在實盤/模擬盤再次驗證。**
