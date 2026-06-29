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

## 4. 結論

- **通用策略結案**：Phase 2 retest 假說否定、SR-channel 突破/回測**無跨商品穩健 edge**（GBP 虧、AUD 平、XAU 爆）。最佳版本是裸突破。
- **EURUSD 專用 breakout 晉級**：單商品裸突破通過 walk-forward + 逐年 + 成本壓測，已移入 `Strategy_Live_Candidates/` 等待 demo forward 實戰檢驗。
- 指標 Phase 1（ATR 寬度、量過濾）+ Phase 2（retest buffer）程式碼保留可用。

## 5. 後續

1. **EURUSD 線 → demo forward**（見部署卡）；統計級確認需 6–12 個月。
2. （獨立小任務）修正 `OnTester`：加 PF 下限、DD 上限懲罰，避免最佳化偏向過度交易組。

## 6. 已知無效 / 注意事項

- `ChannelWidthPct` 在 1–4 對結果無效（鏈接飽和）；高波動商品（XAUUSD）的 ATR 風險手數會放大回撤，需另行檢視風控。
- 所有結果皆為 in-sample 或單次 OOS，**非 live readiness**；尚未納入 commission/swap、broker 差異與多 regime 壓力。
