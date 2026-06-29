# SNR 未走完的優化方向（待辦索引）

更新日期：2026-06-30

本檔是 SNR / SR Channel 研究的「**未走完方向**」總索引，方便下次打開 repo 一眼看到還能做什麼。
背景：SR-channel 通用策略已結案，**EURUSD 專用 breakout 晉級**（見 [部署卡](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md)、[研究紀錄 S1–S7](../Strategy_Records/Strategy_SR_Channel_Breakout.md)）。以下方向多數可套用於提升 EURUSD 線或開新線。

詳細想法多數已在 [SNR_External_Ideas_Harvest.md](SNR_External_Ideas_Harvest.md) §2。

## 🟢 已建好、但從沒實測過（最划算，純回測）

| # | 方向 | 說明 | 狀態 |
|---|---|---|---|
| 1 | **量過濾突破 `UseVolumeFilter`** | Phase 1 已實作、預設關閉、**一次都沒測過**。正是打「假突破」（害死 GBP/AUD 的元兇）。在 EURUSD A/B（false vs true，掃 `VolMult` 1.0/1.2/1.5），可能再推高 PF、甚至回救其他商品。**首選。** | 待測 |
| 2 | **ATR 自適應通道寬度 `ChannelWidthMode=WIDTH_ATR`** | Phase 1 已實作、從沒 A/B。理論上比 Range% 更貼近近期波動。純回測。 | 待測 |

## 🟡 已記錄、未實作（依價值）

| # | 方向 | 說明 | 文件 |
|---|---|---|---|
| 3 | **HTF confluence（高時框濾網）** ★★ | EA 端掛第二個 iCustom（D1/H4 的 SR），被高時框反向位擋住就不進場。**不用改指標。** | Harvest §2-D |
| 4 | **自適應 pivot 取樣窗** ★★ | 用「最近 N 個 pivot」取代固定 290 根，S/R 更聚焦近期。 | [Adaptive_Pivot_Window](SRChannel_Adaptive_Pivot_Window_Upgrade.md) |
| 5 | **強度 aging + freshness** ★★ | 通道老化衰減 + 觸碰新鮮度；與 #4 同向，建議合併設計。 | Harvest §2-F |
| 6 | **Proximity / approach 過濾** ★ | 用既有 nearest res/sup 過濾遠距訊號。 | Harvest §2-E |
| 7 | **Volume Profile S/R** ☆ | 與 pivot 正交的另一套方法論，**另開獨立指標**，工程量大。 | Harvest §2-G |

## 🔧 研究中發現、待修的技術債

| # | 項目 | 說明 |
|---|---|---|
| 8 | **修 `OnTester` 評分** | 目前 `recovery × PF × √trades` 會偏好「過度交易薄邊際」組（S3 發現）。加 PF 下限 + DD 上限懲罰。**正式再最佳化前應先修。** |
| 9 | **`ChannelWidthPct` 結構問題** | 在 1–4 完全無效（分群無限鏈接超過 cwidth，S3 發現）。修了 width 才是有意義的可調參數。 |

## 🔵 另一條獨立方向（不同策略）

| # | 方向 | 說明 | 文件 |
|---|---|---|---|
| 10 | **PrecisionSniper + SNR 位置過濾** | 用 SNR 當另一支 EA 的進場位置濾網，與 breakout 完全不同玩法。標為「優先研究方向」。 | [PrecisionSniper_SNR_Filter](PrecisionSniper_SNR_Filter.md) |

## 建議下次的起手式

1. **先測 #1 量過濾**（已建好、直接打假突破、可能同時提升 EURUSD 並回救其他商品）。
2. 要正式再跑最佳化前，**先修 #8 OnTester**，避免被過度交易組帶歪。
3. 想要結構升級提升訊號品質 → **#3 HTF confluence**（EA 端、不動指標）。

## 相關文件

- [外部 SNR 想法彙整](SNR_External_Ideas_Harvest.md)
- [研究紀錄 S1–S7](../Strategy_Records/Strategy_SR_Channel_Breakout.md)
- [EURUSD 部署卡](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md)
