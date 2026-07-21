# 部署卡：SR Channel Breakout — EURUSD 專用

狀態：**⛔ 暫停使用 — 驗證證據失效，調查中**（2026-07-21）
建立日期：2026-06-30

> ## ⛔ 本卡的績效數字對應的不是本卡的參數，不可部署
>
> 2026-07-21 查明：本卡 §3 的驗證數據（PF 1.47 / +2573 / 103 筆）是在**參數傳遞錯誤**的情況下產生的。當時的 EA 以 positional `iCustom` 傳參，而 `Support_Resistance_Channels.mq5` 的第一個宣告是 `input group "Settings"`——**`input group` 會佔用一個 `iCustom` positional 參數位**，導致 14 個參數整體前移一位。
>
> 指標實際收到的是（`EFFECTIVE` 實測）：
>
> | | 本卡宣稱 | 指標實收 |
> |---|---|---|
> | PivotPeriod | 10 | **4** |
> | ChannelWidthPct | 2 | **1** |
> | MaxNumSR | 3 | **10** |
> | Loopback | 290 | **100** |
> | SourceMode | High/Low | **2（落入 Close/Open 分支）** |
> | UseVolumeFilter | false | **true**（VolMaLen=1, VolMult=0.1）|
>
> 2026-07-02 的 commit `65062e9` 改用 global variable override，**意外修好了這個 bug**（override 在 positional 之後覆寫，蓋掉了錯位的值）。以修好後的程式碼、用本卡宣稱的參數重跑：
>
> | Build | CWP / MaxSR | 交易數 | PF |
> |---|---|---:|---:|
> | `26e0f6a`（本卡數據來源）| 2 / 3 | 103 | **1.466** |
> | 現行 HEAD | 2 / 3 | 2088 | 0.999 |
> | 現行 HEAD | 5 / 6 | 3639 | 0.906 |
>
> 訊號層級比對（`Utilities/SRChannel_Signal_Diff.mq5`）確認分歧在指標訊號產生階段：同樣名目參數下，修正後 7.05% 的 K 棒有突破訊號，修正前只有 0.29%。
>
> **結論：§2 的參數表與 §3 的績效數字從未對應過。** 用宣稱的參數跑，策略沒有 edge（2088 筆 / PF 0.999）；PF 1.47 屬於上表右欄那組沒有人打算使用的參數。
>
> **edge 本身是真的。** 2026-07-21 以修正後的程式碼刻意設定成右欄那組參數重跑，精確重現：103 筆、PF 1.466、淨利 +2572.71（見 [Strategy_Records](../Strategy_Records/Strategy_SR_Channel_Breakout.md) S10.3）。
>
> **在重驗結束前：**
> - 不可依本卡部署 demo 或 live。
> - S1–S7 的所有回測結論一併失效（皆跑在錯位參數上）；S9 退回待測。
> - 新參數組**僅有單次全期 in-sample 結果**，尚未經 walk-forward、逐年、跨商品或成本壓測。本卡待該序列完成後重寫。

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

> 可直接載入 preset：[SR_Channel_Breakout_EURUSD.set](SR_Channel_Breakout_EURUSD.set)（內容與下表一致；enum 以整數表示。若 MT5 無法解析，請在終端手動輸入一次後由 MT5 另存覆蓋，並回報格式差異）。

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
