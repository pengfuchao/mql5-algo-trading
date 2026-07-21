# SNR 未走完的優化方向（待辦索引）

更新日期：2026-06-30

本檔是 SNR / SR Channel 研究的「**未走完方向**」總索引，方便下次打開 repo 一眼看到還能做什麼。
背景：SR-channel 通用策略已結案，**EURUSD 專用 breakout 晉級**（見 [部署卡](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md)、[研究紀錄 S1–S7](../Strategy_Records/Strategy_SR_Channel_Breakout.md)）。以下方向多數可套用於提升 EURUSD 線或開新線。

詳細想法多數已在 [SNR_External_Ideas_Harvest.md](SNR_External_Ideas_Harvest.md) §2。

> ⛔ **2026-07-21：本檔多數內容待重整。** 研究紀錄 S10 查明 S1–S9 跑在錯位的 `iCustom` 參數上（`input group` 佔用 positional 參數位）。下表兩項「已否定」退回**待測**，#9 `ChannelWidthPct` 技術債已確認是錯位的產物而非真實現象。狀態以[研究紀錄 S10](../Strategy_Records/Strategy_SR_Channel_Breakout.md) 為準。

## ⚠️ 曾標為已否定，現退回待測（原據 S9，已因 S10 失效）

| # | 方向 | 結果 | 狀態 |
|---|---|---|---|
| 1 | **量過濾突破 `UseVolumeFilter`** | IS 的 PF/Expected Payoff 確實提高（`VolMult=1.2` → PF 1.709），但**交易數由 103 降到 60，Back/Front 驗證 forward 明顯弱化**（Front PF 1.367、28 筆），Recovery/DD 未優於 baseline。 | **否定**，不替代 baseline |
| 2 | **ATR 自適應通道寬度 `WIDTH_ATR`** | 交易數由約 103 暴增至 1464–2377，**PF 全部 < 1、DD 46–81%**。channel geometry 被改成大量 false breakout，不是可優化高原。 | **否定**，不做 Back/Front |

> ⚠️ 索引曾長期標示這兩項為「待測」，實際上研究紀錄 S9 已完成並否定。**狀態以 [研究紀錄](../Strategy_Records/Strategy_SR_Channel_Breakout.md) 為準。**

### 從 S9 學到的方向性結論

EURUSD baseline 只有 **約 16 筆/年（6 年 103 筆）**。`UseVolumeFilter` 的失敗模式值得記住：**它確實提升了每筆品質，但把樣本砍到 forward 期不足 30 筆，統計上就守不住了。**

推論：**對這條低頻線而言，任何「進場過濾器」都是錯誤方向** —— 它們必然減少交易數，而這條線的樣本數本來就是瓶頸。應優先考慮**不減少交易數、但放大每筆 edge 的改動（主要是出場）**。

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
| 8 | **修 `OnTester` 評分** | **已完成**：加入最低交易數、PF 下限、DD 上限與交易數 boost 上限，避免 `recovery × PF × √trades` 偏好過度交易薄邊際組。後續 optimization 應使用新 Custom criterion。 |
| 9 | **`ChannelWidthPct` 結構問題** | 在 1–4 完全無效（分群無限鏈接超過 cwidth，S3 發現）。修了 width 才是有意義的可調參數。 |

## 🔵 另一條獨立方向（不同策略）

| # | 方向 | 說明 | 文件 |
|---|---|---|---|
| 10 | **PrecisionSniper + SNR 位置過濾** | 用 SNR 當另一支 EA 的進場位置濾網，與 breakout 完全不同玩法。標為「優先研究方向」。 | [PrecisionSniper_SNR_Filter](PrecisionSniper_SNR_Filter.md) |

## 建議下次的起手式

> 2026-07-20 更新：原本列的前兩項（#1 量過濾、#2 `WIDTH_ATR`）**已於 S9 測完並否定**，不要再跑。

1. **啟動 EURUSD 線的 demo forward**（部署卡自 2026-06-30 起即為「待啟動」）。這條線的瓶頸是樣本，不是參數；demo 是目前唯一能增加樣本的動作。
2. **出場端 A/B**（breakeven / partial close / Chandelier 追蹤）——**不減少交易數**，符合 S9 與 [workflow Step 0.5](../Strategy_Records/MT5_Strategy_Research_Workflow.md) 的方向性結論。目前 EA 只有固定 ATR SL + RR TP，無 trailing / breakeven / 部分平倉，是最大的未探索面。
3. **進場過濾器（#3 HTF confluence、#6 proximity、Squeeze 閘門）一律降級**：六年僅 103 筆，任何濾網都會把 forward 樣本壓到統計失效。若仍要做，須事前寫下最低 forward 交易數門檻（建議 ≥ 30），未達即判否定。

## 相關文件

- [外部 SNR 想法彙整](SNR_External_Ideas_Harvest.md)
- [研究紀錄 S1–S7](../Strategy_Records/Strategy_SR_Channel_Breakout.md)
- [EURUSD 部署卡](../Strategy_Live_Candidates/SR_Channel_Breakout_EURUSD.md)
