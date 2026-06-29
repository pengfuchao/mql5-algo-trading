# 部署卡：SR Channel Breakout — EURUSD 專用

狀態：**demo forward 待啟動**（回測全關通過）
建立日期：2026-06-30

- EA：[`Strategies/Strategy_SR_Channel_Breakout.mq5`](../Strategies/Strategy_SR_Channel_Breakout.mq5)
- 指標（須先編譯並置於 `MQL5\Indicators\`）：[`Indicators/Support_Resistance_Channels.mq5`](../Indicators/Support_Resistance_Channels.mq5)
- 完整研究證據：[Strategy_Records/Strategy_SR_Channel_Breakout.md](../Strategy_Records/Strategy_SR_Channel_Breakout.md)（S3–S7）

> ⚠️ 本卡設置已寫死且驗證過。**實戰中不可直接改參數**；任何更動都要回 `Strategy_Records/` 重驗。

## 1. 市場 / 環境

| 項目 | 值 |
|---|---|
| 幣種 | **EURUSD**（單商品；其他商品已驗證無效，勿套用）|
| 週期 | **H1** |
| 帳戶類型 | Hedging 較佳；Netting 下若 symbol 有他人部位 EA 會拒進場 |
| 建議 broker | 與回測同條件（ECN，commission ≈ $7/手來回）|

## 2. 完整 Input 設置（寫死）

**S/R Indicator**（順序即 iCustom 計算參數順序，務必一致）
| Input | 值 |
|---|---|
| InpIndicatorName | `Support_Resistance_Channels` |
| InpPivotPeriod | 10 |
| InpSourceMode | High/Low (0) |
| InpChannelWidthPct | 2 |
| InpMinStrength | 1 |
| InpMaxNumSR | 3 |
| InpLoopback | 290 |
| InpChannelWidthMode | Range % (0) |
| InpATRLen | 14 |
| InpATRMult | 0.3 |
| InpUseVolumeFilter | false |
| InpVolMaLen | 20 |
| InpVolMult | 1.0 |
| InpRetestTolerATR | 0.10 |
| InpRetestExpiryBars | 20 |

**Signal**
| Input | 值 |
|---|---|
| InpSignalMode | **SIG_BREAKOUT (0)** |

**Trade**
| Input | 值 |
|---|---|
| InpMagic | 770010 |
| InpDeviation | 20 |
| InpMaxSpreadPts | 30.0 |
| InpCloseOnReverse | true |
| InpOnePosition | true |
| InpMaxPositions | 5 |
| InpTradeOnFirstBar | false |

**Sizing & Risk**
| Input | 值 |
|---|---|
| InpUseRiskSizing | true |
| InpRiskPercent | **1.0** |
| InpFixedLots | 0.10 |
| InpATRPeriod | 14 |
| InpSLMultiple | 1.5 |
| InpTPRatio | 2.0 |

> `ChannelWidthMode=Range%` 下 `ATRMult`、以及 breakout 模式下 `RetestTolerATR/ExpiryBars` 不參與運算，但須照表填以對齊 iCustom 參數位置。

## 3. 驗證摘要（USDJPY/其他僅供對照，本卡僅 EURUSD）

| 關卡 | 結果 |
|---|---|
| 全期 real ticks（2020.06–2026.06）| PF **1.47**、+2573、103 筆、最大回撤 4.95% |
| Walk-forward（內建 Forward 1/3，Sharpe）| MinStr1/MaxSR3 在 IS↔Forward 皆贏（穩定高原）；IS 最佳組 Forward PF 1.46 |
| 逐年穩定性（6 年窗，固定配置）| **6/6 年正**，非單年撐起，勝率 ~30–40% |
| **成本壓測**（commission $7/手來回）| **PF 1.42、淨利 +2180** → 影響小、edge 維持 |

策略 profile：低勝率（~34%）、靠賠率（RR 2.0）、低頻（**~16 筆/年**）。

## 4. 風控與部位規則

- 每筆風險 **1% equity**（動態手數，EA 內建 fail-closed）。
- **單商品集中度高** → 實盤初期建議再保守（如 0.5%）直到 demo/live 累積信心。
- 預期會有連續虧損段（回測曾見最大連虧數筆）；不可手動干預 EA 邏輯。
- 留倉過夜 → **swap 成本需納入監控**（demo 階段確認）。

## 5. Demo forward 檢查清單

- [ ] 指標已編譯、置於 `MQL5\Indicators\`；EA 載入無「無法載入指標」錯誤。
- [ ] 掛 EURUSD H1，input 與 §2 完全一致。
- [ ] 觀察前幾筆：進場在正確 K 棒、SL/TP 掛對、手數合理。
- [ ] 記錄**實際滑點 / 進場點差 / swap** vs 回測。
- [ ] Journal 無重複下單、無 retcode 錯誤。
- [ ] 期待值：2–3 個月僅 ~3–6 筆 → 此階段重點是**執行正確性**，非統計顯著。

## 6. 停用條件 (Kill criteria)

出現以下任一，**暫停並回 `Strategy_Records/` 檢討**：

1. demo/live 實際滑點或點差使單筆成本顯著高於壓測假設（$7/手來回）。
2. 累積到合理樣本（≥30 筆）後 **PF < 1.1** 或淨值新低超過回測最大回撤（~8%）一定幅度。
3. 連續虧損筆數明顯超過回測歷史。
4. EA 行為與回測不符（訊號棒、SL/TP、手數），排查後仍無法對齊。

## 7. 變更紀錄

| 日期 | 變更 |
|---|---|
| 2026-06-30 | 建立部署卡，回測全關通過，狀態＝demo forward 待啟動 |
