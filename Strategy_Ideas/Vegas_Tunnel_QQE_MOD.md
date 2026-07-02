# Vegas Tunnel + QQE MOD Strategy Idea

建立日期：2026-07-03

狀態：策略發想 / 待評估（尚未實作，低期望探索）

## 1. 核心想法

用兩支指標組成典型「趨勢濾清 + 動能觸發」順勢回踩系統：

```text
Vegas Tunnel  → 決定「只做多還是只做空」（regime / 方向偏好 + 動態 S/R）
QQE MOD       → 決定「什麼時候進場」（動能確認，濾掉無效震盪）
```

- **Vegas Tunnel**：由 EMA 144 與 EMA 169 組成的「隧道」帶（選配 EMA 12 / 24 作快線輔助）。價格穩定在隧道上方 → 多頭 regime；下方 → 空頭 regime。隧道本身當作動態支撐/阻力帶，回踩不破為順勢加碼點。
- **QQE MOD**：RSI 平滑後的動能振盪器（Wilder 平滑 RSI + RSI 的 ATR 追蹤帶，MOD 版另加 RSI 上的 Bollinger 判定與著色直方圖）。由紅轉藍 / 突破零軸 → 多頭動能爆發，反之為空。

這不是把任一支當獨立訊號，而是 **Tunnel 給方向、QQE 給時機** 的雙層結構。

## 2. 策略假說

- 單靠動能指標（如 QQE 或 PrecisionSniper）在盤整區會產生大量假訊號。
- 先用 Vegas Tunnel 過濾方向，只在 regime 一致方向進場，可去掉逆勢雜訊。
- 在多頭 regime 下，價格回踩隧道帶（EMA144/169）不破、QQE 再次翻多 → 較佳 risk-reward 的順勢進場點。
- 預期：降低逆勢交易、提高 Expected Payoff 與 PF，代價是交易數下降、且高度依賴市場是否處於趨勢 regime。

## 3. 使用元件

### 3.1 Vegas Tunnel（趨勢濾清 + 動態 S/R）
- **可原生於 EA 內計算**：`iMA(EMA, 144)`、`iMA(EMA, 169)`，選配 `iMA(EMA, 12)`、`iMA(EMA, 24)`。
- 不需要外部自訂指標 → **不會遇到 SNR 那次「iCustom buffer 在 tester 回傳 0」的問題**（這是相對 SNR 案的重要優勢）。

### 3.2 QQE MOD（動能確認）
- QQE MOD 非內建，需其一：
  1. 取用社群自訂指標（TradingView 版常見作者 Mihkel00），以 `iCustom` 讀已收盤棒 buffer；**若採此路，第一步就要先驗證該指標 buffer 在 Strategy Tester 用 iCustom 能正確填值**（吸取 SNR 教訓）。
  2. 在 EA 內自行實作：`RSI(len)` → Wilder 平滑 → RSI 的 ATR 追蹤帶（fast/slow QQE line），可省掉 iCustom 依賴，但程式量較大。
- **建議優先走 (2) 在 EA 內自算**，把外部依賴降到零。

### 3.3 出場與風控（沿用 repo 既有慣例）
- ATR × 倍數止損、RR 比例止盈（同 `PrecisionSniperEA` / `Strategy_SR_Channel_Breakout`）。
- 可直接掛既有短線控制：`MaxHoldingBars`、`SessionFilter`、`MaxSpread`、Friday exit。

## 4. 進場條件（機械化定義）

方向 regime（收盤價 `C[1]`）：
- **Long-only**：`C[1] > EMA144` 且 `C[1] > EMA169`。
- **Short-only**：`C[1] < EMA144` 且 `C[1] < EMA169`。
- 隧道之間（價格夾在兩線內）：不進場。

進場觸發（在對應 regime 下）：
- **基本版**：QQE MOD 由空翻多（動能線上穿門檻/零軸）→ 開多；反之開空。
- **回踩版（品質較高、交易更少）**：價格先回踩到隧道帶（觸及 EMA144/169 區間）後收回不破，QQE 再確認同向 → 進場。
- 同一根同時出現多空條件視為不明確 → 跳過。
- 只讀已收盤棒（`shift=1`），避免盤中 repaint。

## 5. 過濾條件
- Regime 一致性（上方硬條件）。
- 選配 EMA12/24 作額外動能對齊（例如 EMA12 在 EMA24 上方才允許做多），但**每多一層都增加過擬合面積**，第一輪建議先不加。
- MaxSpread / Session 時段過濾（沿用）。

## 6. 出場與風控
- ATR SL + RR TP；方向感知量化 SL/TP。
- `MaxHoldingBars` 限制持倉、Session 只在指定時段開新倉、週五提前收倉降低 weekend/rollover exposure。
- 反向訊號：先平反向倉，若當下不允許新倉則不反手（同 repo 慣例）。

## 7. 第一輪測試計畫
1. **固定參數、先跑 baseline**（不要一開始就 grid search 4 條 EMA）：
   - 商品/週期：先 `USDJPY / M15`（repo 目前最強短線候選）與 `EURUSD / H1` 各一。
   - 參數寫死：EMA 144/169、QQE 預設（RSI 14、SF 5、門檻預設）、ATR SL 1.5、TP RR 2.0。
   - 期間：2020.06–2026.06，real ticks。
2. **年度拆分** + Forward/OOS + **成本壓測**（spread / commission / slippage / delay），同 `Strategy_Records` 第 8 節決策標準。
3. 只有 baseline 有正期望，才考慮小幅 A/B（例如回踩版 vs 基本版、要不要加 EMA12/24），且**IS 改善但 OOS/Forward 沒改善 → 視為 data mining，不晉級**。

## 8. 量化角度：這個組合有沒有價值？（誠實評估）

**結論：值得跑一次當低成本假說，但先驗機率偏低，別當「聖杯」投入太多輪。**

正面：
- **邏輯結構是對的**：趨勢濾清 + 動能觸發，是很多可行順勢系統的骨架。
- **實作成本低、無外部依賴風險**：Tunnel 可用 `iMA` 原生算；QQE 若在 EA 內自算則完全不依賴 iCustom，避開 SNR 那次的技術陷阱。
- **與 repo 既有研究框架相容**：可直接掛既有 Session/MaxHolding/Spread 控制,套用同一套決策標準驗證。

保留意見（量化員視角）：
- **兩支都是「落後、由價格/RSI 衍生」的指標**：Tunnel 是慢速 EMA band、QQE 是平滑 RSI，**資訊來源同質**（都來自價格），沒有引入獨立資訊（量、波動 regime、結構）。兩個落後指標相疊,主要效果是**減少交易數**,不必然產生新 edge。
- **EMA 144/169 沒有特殊魔力**：這組數字是坊間 Fibonacci 傳說（144 是 Fib、169=13²），量化上與任何一組「相近週期的慢速 MA」無本質差異。不要賦予它超額意義。
- **參數面積大 → 過擬合風險高**：4 條 EMA + QQE(RSI len/SF/門檻/BB len/mult)。很容易把 2020–2025 調到漂亮但 OOS 崩掉。**這是最大風險。**
- **regime 依賴**：趨勢年賺、盤整年被隧道內外反覆巴 —— 這正是 repo 裡 PrecisionSniper 與 SR channel 已經反覆出現的病。預期它也會有「某些年才賺」的不穩定性。
- **極度大眾化**：這是零售最常見的模板之一，明顯 edge 大多已被競爭掉。真正決定盈虧的通常是**出場/風控/商品時段選擇**,而不是指標本身。

一句話：**把它當成「又一個要用同一套嚴格關卡去證偽的順勢候選」,不是新武器。** 先驗成本低、值得排進 backlog，但心理預期要放在「大概率會 regime-dependent」。

## 9. 進入 `Strategy_Records/` 的條件
- 完成 baseline（固定參數）回測且**長樣本正期望**。
- 跨年度拆分不是只靠單一年份。
- Forward / OOS 與成本壓測後仍接近正期望。
- 至少一個商品/時段組合達到第 8 節決策標準（PF ≥ 1.15、Expected Payoff > 0、Sharpe 明顯優於既有 baseline、交易數足夠、多 regime 不全面失效）。

## 相關文件
- 決策標準與研究流程：[../Strategy_Records/MT5_Strategy_Research_Workflow.md](../Strategy_Records/MT5_Strategy_Research_Workflow.md)
- 同類「訊號 + 過濾」教訓（iCustom buffer 陷阱）：[../Strategy_Records/PrecisionSniperEA.md](../Strategy_Records/PrecisionSniperEA.md)（第 4.3 節）
