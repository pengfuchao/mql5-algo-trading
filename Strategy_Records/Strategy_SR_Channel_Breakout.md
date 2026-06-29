# SR Channel Breakout — 研究紀錄

EA：[`Strategies/Strategy_SR_Channel_Breakout.mq5`](../Strategies/Strategy_SR_Channel_Breakout.mq5)
指標：[`Indicators/Support_Resistance_Channels.mq5`](../Indicators/Support_Resistance_Channels.mq5)
相關發想：[Phase 1/2 規劃彙整](../Strategy_Ideas/SNR_External_Ideas_Harvest.md)

建立日期：2026-06-29

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

## 4. 結論

- 純突破訊號**不足以成為可部署的穩健策略**；但 EURUSD 的表現顯示「SR 通道」底層結構有東西，問題在裸突破訊號品質不足（易被假突破洗，GBP 勝率僅 22%）。
- 決策：**保留結構、升級訊號** → 進行 Phase 2（SBR/RBS 回測進場），以「能否讓跨商品翻正」作為此策略生死的最終判準。

## 5. 下一步測試計畫

1. 實作 Phase 2（回測進場）：見 [SRChannel_Retest_SBR_RBS_Upgrade.md](../Strategy_Ideas/SRChannel_Retest_SBR_RBS_Upgrade.md)。
2. 重跑 S5 跨商品（改用 `SIG_RETEST`），比較是否多數商品翻正。
3. 若 retest 跨商品穩健 → 對存活商品做 walk-forward + SL/TP 第二階段最佳化 + spread/slippage stress。
4. 順帶修正 `OnTester`（加 PF 下限、DD 上限懲罰），避免最佳化偏向過度交易組。

## 6. 已知無效 / 注意事項

- `ChannelWidthPct` 在 1–4 對結果無效（鏈接飽和）；高波動商品（XAUUSD）的 ATR 風險手數會放大回撤，需另行檢視風控。
- 所有結果皆為 in-sample 或單次 OOS，**非 live readiness**；尚未納入 commission/swap、broker 差異與多 regime 壓力。
