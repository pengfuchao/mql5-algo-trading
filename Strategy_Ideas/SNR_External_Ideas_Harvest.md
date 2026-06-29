# 外部 SNR 指標想法彙整（6 支 TradingView 指標審視）

建立日期：2026-06-29

狀態：彙整 / 待逐項評估與選擇性實作

審視對象（皆為 TradingView Pine 指標，僅取「方法與想法」，不照搬程式碼；採用時各依其授權標註來源）：

1. MTF Support / Resistance Channels — © TradeSymbiotic（MPL-2.0）
2. Support/Resistance Breakout Detector
3. Malaysian SnR and Decision Levels [DoN]
4. Malaysian SnR Levels [UAlgo]（CC BY-NC-SA 4.0）
5. Liquidity Structure Mapper [JOAT] — © officialjackofalltrades（MPL-2.0）
6. HexaTrades VRVP Volume Profile S/R Matrix

## 0. 對照基準（我們現有的 SRchannel）

升級評估一律對照現有不變量與能力：

- **closed-bar 因果性**（shift=1 已收盤棒判定，永不用形成中 bar0）、**每根新棒才重算、不 repaint**。
- 通道來源：pivot 群聚成 zone；**強度 = pivot 數×20 ＋ loopback 內 high/low 觸及通道的 bar 數**。
- 已輸出訊號：Breakout（突破）、Bounce（影線拒絕）、nearest res/sup buffer，供 EA 以 iCustom 讀取。
- 既有研究文件：[新增反彈訊號](SRChannel_Bounce_Signal_Upgrade.md)、[自適應 pivot 取樣窗](SRChannel_Adaptive_Pivot_Window_Upgrade.md)。

## 1. 逐支審視結論

### #1 MTF Support / Resistance Channels（TradeSymbiotic）
- 🟢 **ATR 自適應通道寬度**：`half_w = ta.atr(len) × mult`，zone 厚度隨波動自動縮放。我們現用「近 300 根 (high−low) × ChannelWidthPct%」屬全域尺度；ATR 更貼近近期波動。→ 見 §2-C。
- 🟢 **多時間框架 (HTF) pivot**：H1/D/W 的 S/R 疊到當前圖。→ 見 §2-D。
- 🟡 **Proximity filter**：隱藏離現價 >X% 的 zone。我們已算 nearest res/sup，可加距離閘門。→ 見 §2-E。
- ⚪ 畫法 / linefill / label：純視覺，對 EA 無益。

### #2 Support/Resistance Breakout Detector
- 🟢 **成交量確認突破**：`close > level and volume > 門檻` 才算有效突破。我們**完全無量過濾**。
  - ⚠️ 它用**絕對量** `1000000` → 對 FX/CFD/不同商品不可移植。採用時務必改為**相對量**（`volume > volume_MA × k`）。→ 見 §2-A。
- ⚪ 碰觸即停延伸、bull/bear wick 標籤：我們的反彈/拒絕邏輯已涵蓋同義概念。

### #3 Malaysian SnR and Decision Levels [DoN]
- 🟢🟢 **角色反轉 (SBR/RBS) + 回測**：價位被突破後**不刪除**，翻成反向角色（支撐破→變壓力 SBR；壓力破→變支撐 RBS），並偵測「回測該翻轉位」。**本批最具交易價值的概念**。→ 見 §2-B。
- 🟡 HTF 疊加（同 #1）。
- 🟡 H4 Decision Level：連續兩根同向 K 的 gap 取 open 當決策位 — 較 niche，暫不列優先。
- ⚪ touch / retest 警示：概念併入 §2-B/E。

### #4 Malaysian SnR Levels [UAlgo]（CC BY-NC-SA）
- 🟢 **Fresh / Unfresh 新鮮度**：未被測過的位最「鮮」（實線、粗），首次 wick 觸碰後降級為 unfresh（虛線、淡）。與我們「觸碰越多越強」是**相反哲學**；實務上兩者都對 —— 頭幾次測試最會守、測太多次反而易破。→ 見 §2-F。
- ⚪ cross 判定（open/close + 前一收盤）與我們 closed-bar 思路一致，無新意。
- ⚪ Gap level、MTF：分別同 #3 / #1。

### #5 Liquidity Structure Mapper [JOAT]（MPL-2.0）
- 🟢 **多因子強度 = 觸碰分 + 年齡分 + 寬度分**，且含 **age decay（zone 越舊分數越低）**。我們的強度無「老化」維度。此點與 [自適應 pivot 窗](SRChannel_Adaptive_Pivot_Window_Upgrade.md) 互補。→ 見 §2-F。
- 🟡 **EQH/EQL（等高/等低＝流動性池）+ sweep（掃單後反轉）**：我們的 pivot 群聚 + 影線拒絕 (Bounce) 已部分涵蓋；sweep 即「假突破後收回」，與 Bounce 同源。低優先。
- ⚪ Dashboard / 視覺特效：無益。

### #6 HexaTrades VRVP Volume Profile S/R Matrix
- 🟢🟢 **成交量分佈 (Volume Profile) 求 S/R**：建 volume-by-price 直方圖，HVN（高量節點）＝強 S/R，含 POC / VAH / VAL / LVN。與 pivot **完全正交**的另一套方法論，價值高但工程量大。→ 宜另開**獨立指標**，見 §2-G。
- 🟢 **相對量確認**（`volume > ta.sma(volume, len)`）：§2-A 的正確示範（對照 #2 的絕對量錯誤）。
- 🟢 **approach 預警**：價接近 zone 前（距離 ≤ X%）先發訊號，利於預備進場。→ 見 §2-E。
- 🟡 POC/VAH/VAL（value area）、買賣量拆分：屬 Volume Profile 套件，隨 §2-G 一起。

## 2. 去重後的可採用想法（依優先級）

### A.（★★★）量確認突破 — 低成本高效益
- **作法**：突破 buffer 寫值前，加閘門 `tick_volume[1] > k × SMA(tick_volume, n)`（用**相對量**，FX 以 tick volume 為 proxy）。
- **介面**：指標加 `UseVolumeFilter`、`VolMaLen`、`VolMult`；不影響現有 buffer 結構，EA 端無需改（訊號仍走原 buffer）。若做成 input 則 iCustom 簽章需同步（見相容性註）。
- **動機**：直接打掉低量假突破，是六支裡 CP 值最高的補強。

### B.（★★★）角色反轉 + 回測進場 (SBR/RBS) — 高交易 edge
- **概念**：突破發生後，被突破的通道**翻為反向角色並保留**；價格**回測**該翻轉位且守住，才是高品質進場（取代裸突破追價）。
- **與現有銜接**：我們已有 Breakout 與 Bounce 兩類訊號；SBR/RBS 等於「先 Breakout 標記翻轉位 → 後續在該位出現 Bounce/守住 → 發 Retest 訊號」。可新增 `RetestBuy/RetestSell` buffer，EA 加 `SIG_RETEST` 模式（沿用 [反彈升級](SRChannel_Bounce_Signal_Upgrade.md) 的對稱寫法）。
- **狀態保存**：需保存「最近被突破的位 + 方向 + 是否已回測」少量 stateful 資訊，但仍以 closed-bar 更新，不破壞因果性。

### C.（★★）ATR 自適應通道寬度 — 低成本
- **作法**：新增寬度模式 `ChannelWidthMode = {Range%, ATR}`；ATR 模式下 `cwidth = ATR(len) × mult`。
- **動機**：盤勢波動變化時 zone 厚度自動跟上，避免固定 % 在低波動過寬、高波動過窄。
- **風險**：ATR 太短會使通道逐棒抖動，需與 closed-bar 重算搭配測試。

### D.（★★）HTF S/R confluence — 高值高成本
- **作法**：指標以更高 TF 的 series（`CopyRates`/多 handle）計算 pivot S/R，輸出「最近 HTF 壓力/支撐」buffer；EA 用作 confluence 濾網（如：僅當突破方向不被就近 HTF 反向位擋住才進場）。
- **成本**：需處理 HTF 對齊、重繪、causality；屬獨立一輪較大改動，建議排在 A/B/C 之後。

### E.（★）Proximity / Approach 狀態 — 低成本便利
- **作法**：利用既有 nearest res/sup，新增 `near zone within X%` 旗標 / approach buffer。EA 可據此預備反彈單或過濾遠距訊號。

### F.（★★）強度加入「年齡衰減 + 新鮮度」維度 — 精修 strength
- **概念整合**：JOAT 的 age decay（越舊越弱）＋ UAlgo 的 freshness（未測最鮮、過度測試轉弱）。
- **作法**：在現有強度（pivot 群聚 + bar 觸碰）之外，疊加 (i) 年齡衰減係數、(ii) 觸碰次數的**非單調**處理（首幾次加分、過多扣分），並可把「觸碰次數 / 新鮮度」獨立輸出讓 EA 選擇偏好新鮮位。
- **關聯**：與 [自適應 pivot 取樣窗](SRChannel_Adaptive_Pivot_Window_Upgrade.md) 同屬「讓 S/R 更聚焦近期、汰舊」的方向，建議一併設計。

### G.（☆ 另開研究）成交量分佈 (Volume Profile) S/R — 獨立指標
- **作法**：volume-by-price 直方圖 → HVN/POC/VAH/VAL/LVN；與 pivot S/R 正交，可作第二套 S/R 來源或 confluence。
- **定位**：工程量大、方法論不同，**不外掛進現有 SRchannel**，另立新指標研究檔再評估與 EA 的整合。

## 3. iCustom 相容性共通註

凡新增**計算類 input**（A 的量參數、C 的寬度模式、D 的 HTF）都會改變 `iCustom` 參數列 → EA 端須同步加參數並做 buffer 對齊回歸（沿用反彈升級的 shift=1 對齊抽查流程）。可調性 vs 不動 EA 的取捨，逐項於實作時定案。

## 4. 建議落地順序

1. **A 量確認**（最便宜、直接提升突破品質）。
2. **C ATR 寬度**（便宜、改善 zone 本身）。
3. **B 回測進場**（最高交易價值，但需少量 stateful，排在訊號品質補強後）。
4. **F 強度老化/新鮮度** 與 [自適應 pivot 窗](SRChannel_Adaptive_Pivot_Window_Upgrade.md) 合併設計。
5. **D HTF confluence**、**G Volume Profile** 各自獨立較大研究，最後排程。

每項落地前皆需：MetaEditor 0 error/warning → 指標目視 → EA `SIG_BREAKOUT` 回歸須與升級前完全一致 → 新模式 visual 驗證 → spread/slippage stress。

## 相關文件

- [SR Channel 指標升級：新增反彈訊號](SRChannel_Bounce_Signal_Upgrade.md)
- [SR Channel 指標升級：自適應 Pivot 取樣窗](SRChannel_Adaptive_Pivot_Window_Upgrade.md)
- [PrecisionSniper + SNR 位置過濾](PrecisionSniper_SNR_Filter.md)
