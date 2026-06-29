# SR Channel 指標升級：自適應 Pivot 取樣窗（count-based 上限）

建立日期：2026-06-29

狀態：發想 / 待實作

來源：TradingView「Support Resistance - Dynamic v2」(SRv2) © LonesomeTheBlue（我們現有指標移植自同作者的進階版「Support Resistance Channels」，SRv2 為其舊版/簡化版）

## 0. 背景與動機

審視 SRv2 後，**它整體比我們現有的 `Support_Resistance_Channels.mq5` 更簡單**——強度算法較粗（只數 pivot）、突破用中線、且無反彈訊號，這些我們都已做得更好，不值得吸收。

唯一比我們聰明的一點是 **S/R 取樣範圍的定義方式**：

| | S/R 取樣範圍 |
|---|---|
| SRv2（舊版） | **最近 N 個 pivot**（`maxnumpp=20`，count-based） |
| 我們現有 port | 固定 **290 根 bar**（`Loopback`，bar-based，每根重算） |

「固定 bar 窗」的盲點：在**安靜/低波動**行情，290 根內可能只有寥寥幾個 pivot，S/R 樣本不足；在**高波動**行情，290 根內 pivot 過多，舊的、已失效的價位仍被納入，拖累通道與強度判斷。

SRv2 的 count-based 窗天然自適應：**安靜時自動往更遠抓足 N 個 pivot，波動大時自動只看最近 N 個**，讓 S/R 永遠基於「最近 N 次擺動」而非「最近固定時間」。

目標：用最低邊際成本，把這個自適應特性以**可選參數**疊加到現有指標上，不破壞既有 closed-bar 因果性、不 repaint、不改 EA 對接。

## 1. 核心想法

```text
現有：pivot 必須落在「最近 Loopback 根 bar」內才納入
升級：pivot 必須同時滿足 (a) 在最近 Loopback 根內  AND  (b) 屬於最近 MaxPivotCount 個 pivot
      MaxPivotCount = 0 → 不啟用上限，完全等同現行行為（零回歸風險）
```

兩條件取**交集**：bar 窗仍是硬性上界（保留因果性與計算邊界），pivot 計數則在其內再加一道「只看最近 N 次擺動」的自適應濾網。

## 2. 策略假說

- 以「最近 N 次價格擺動」定義 S/R，比「最近固定時間」更貼近市場當前結構，盤勢轉換時 S/R 更快汰舊換新。
- 在低波動盤整段能避免樣本不足；在高波動趨勢段能避免老舊價位干擾 → 兩種 regime 下通道品質都更穩。
- 對 EA 而言，更乾淨、更近期的通道應能降低過時 S/R 造成的假突破/假反彈。

## 3. 使用元件

- Indicator：`Indicators/Support_Resistance_Channels.mq5`（升級對象，僅改 `ComputeSR` 取樣段）
- EA：`Strategies/Strategy_SR_Channel_Breakout.mq5`（**理想上不需改**，見第 4 節 iCustom 相容性決策）
- 不新增外部依賴。

## 4. 實作要點

### 指標 `Support_Resistance_Channels.mq5`

現有 pivot 收集在 `ComputeSR`：以 `i = g_prd+1 .. hiBound` 由近到遠掃描，命中即 `AppendPivot`（陣列 index 0 = 最新 pivot，已對齊 Pine unshift 順序）。

升級只需在 pivot 收集迴圈加一個計數上限：

```text
1. 新增 input MaxPivotCount（Settings 群組，預設 0 = 不限制）。
2. OnInit 夾限驗證（如 0 或 5..100），存入 g_maxpv。
3. ComputeSR 收集迴圈：因掃描本就由最近 pivot 往舊走，
   一旦已收集 pivot 數達 g_maxpv（且 g_maxpv > 0）即 break，
   後續更舊的 pivot 不再納入。
```

> 因現有掃描順序已是「近→遠」，count 上限只是提早結束迴圈，**不需改動 unshift 順序、強度算法、通道選取或繪圖**。改動面極小、風險低。

### iCustom 相容性決策（**需先定案**）

新增計算類 input 會改變 `iCustom` 參數列 → EA 端必須同步加參數，否則對接錯位。三個選項：

1. **加參數並同步改 EA**（最乾淨，但動到 EA 對接，需回歸驗證 buffer 對齊）。
2. **指標內以常數啟用、不開成 input**（EA 完全不動，但失去可調性）。
3. **暫不實作，僅記錄**（本文件即此狀態）。

建議：若決定做，採選項 1，並在同一輪一起回歸驗證（沿用反彈升級的 buffer 對齊抽查流程）。

## 5. 第一輪測試計畫

1. **編譯**：0 errors / 0 warnings。
2. **回歸**：`MaxPivotCount=0` → 指標通道與 EA 交易序列須與升級前**完全一致**。
3. **目視**：開啟 pivot 標籤，確認啟用上限後只保留最近 N 個 pivot、舊 pivot 不再參與通道。
4. **A/B**：固定其他參數，比較 `MaxPivotCount=0`（純 bar 窗）vs 數個 N 值，觀察低波動 vs 高波動段的通道穩定度與訊號品質。
5. 初期商品/週期沿用既有研究慣例（如 USDJPY，與其他 SNR 研究同基準）。

## 6. 可能風險與失效條件

1. N 太小 → S/R 過度貼近近期、頻繁重畫，通道抖動、訊號雜訊上升。
2. N 太大 → 退化回近似純 bar 窗，自適應效益消失。
3. bar 窗與 count 窗交互：若 Loopback 太短，count 上限可能根本碰不到（pivot 不夠多），等於沒作用 → 需文件說明兩者搭配。
4. 不同 symbol 的擺動頻率差異大，最佳 N 不可直接外推。

## 7. 進入正式研究紀錄的條件

A/B 後若某 N 值在通道穩定度或訊號品質上明顯優於純 bar 窗 baseline，且 spread/slippage stress 後仍維持正期望，即可在 `Strategy_Records/` 併入 SR Channel 研究紀錄。

## 8. 不在本次範圍（待審視其他 SNR 後再評估）

- 成交量加權強度、ATR 自適應通道寬度、通道老化淘汰（time-decay）。
- Pine stateful 等價模式、多時間框架 / HTF 濾網。

## 相關文件

- [SR Channel 指標升級：新增反彈訊號](SRChannel_Bounce_Signal_Upgrade.md)（同指標的前一輪升級）
- [PrecisionSniper + SNR 位置過濾](PrecisionSniper_SNR_Filter.md)
