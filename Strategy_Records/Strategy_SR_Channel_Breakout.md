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

## 4. 結論

- **通用策略結案**：Phase 2 retest 假說否定、SR-channel 突破/回測**無跨商品穩健 edge**（GBP 虧、AUD 平、XAU 爆）。最佳版本是裸突破。
- **EURUSD 專用 breakout 晉級**：單商品裸突破通過 walk-forward + 逐年 + 成本壓測，已移入 `Strategy_Live_Candidates/` 等待 demo forward 實戰檢驗。
- Phase 1 filter/width 研究結論：volume filter 技術有效但 forward 不夠穩，`WIDTH_ATR` 技術有效但績效明顯惡化；兩者都**不晉級**，保留程式碼作研究用途。
- 指標 Phase 1（ATR 寬度、量過濾）+ Phase 2（retest buffer）程式碼保留可用，但 EURUSD live-candidate baseline 維持 Range% + no volume filter。

## 5. 後續

1. **EURUSD 線 → demo forward**（見部署卡）；統計級確認需 6–12 個月。
2. SNR 研究線：停止 `WIDTH_ATR` 放大測試；下一步若繼續研究，優先看更嚴格的 breakout confirmation、session/regime filter，或重新設計 channel merge logic。

## 6. 已知無效 / 注意事項

- `ChannelWidthPct` 在 1–4 對結果無效（鏈接飽和）；`WIDTH_ATR` 在 EURUSD H1 breakout 造成交易數暴增與 PF<1；高波動商品（XAUUSD）的 ATR 風險手數會放大回撤，需另行檢視風控。
- 所有結果皆為 in-sample 或單次 OOS，**非 live readiness**；尚未納入 commission/swap、broker 差異與多 regime 壓力。
