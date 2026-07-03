# London Breakout（亞洲盤區間突破）策略想法

建立日期：2026-07-04

狀態：策略發想 / 待實作（外部實證支持中等偏正，時段型策略）

## 1. 核心想法

利用外匯市場最被反覆記錄的**日內結構性現象**：亞洲盤（Tokyo session）波動低、形成窄區間；倫敦開盤（約 08:00 London time）機構訂單流湧入、波動率跳升，價格常沿突破方向延伸。

```text
亞洲盤（00:00–07:59 London time）→ 記錄區間 High / Low
倫敦開盤後                       → 突破區間上緣做多 / 下緣做空
```

這是**時間 + 價格**的策略，不依賴任何技術指標 —— 訊號來源是市場微觀結構（倫敦開盤的流動性與訂單流集中），而不是價格衍生指標。這與 repo 既有的指標型策略（PrecisionSniper、SR Channel）的資訊來源不同質，是其價值所在。

## 2. 策略假說

- 倫敦開盤時段占全球 FX 成交量約 35%+，機構在開盤集中執行隔夜累積的訂單。
- 亞洲盤窄區間 = 隔夜資訊尚未反映；倫敦開盤突破 = 資訊開始定價，具短期延續性。
- 預期：M15 上突破後 2–6 小時內有方向延續，適合 RR ≥ 1.5 的順勢短單。

## 3. 外部實證（寫想法前先查證過）

- [QuantifiedStrategies London Breakout backtest](https://www.quantifiedstrategies.com/london-breakout-strategy/)：以 1.5 RR 止盈回測，**profit factor > 1.5**，回撤有限；並指出 **GBP 系優於 EURUSD**。
- [InsiderFinance 獨立回測](https://wire.insiderfinance.io/backtest-results-revealed-is-the-london-breakout-strategy-worth-it-0e9df65dd63b)：**EURUSD 上常見變體多數虧損** —— 這是重要反證，不是所有商品都有效。
- 綜合判讀：**證據混合但非零**。效果集中在 GBPUSD / GBPJPY 等倫敦時段主場商品；EURUSD 偏弱。任何宣稱月報酬 5–10% 的版本幾乎必是過擬合。

## 4. 進場條件（機械化定義）

以下時間先以 **London time** 定義，實作時換算 broker server time（見第 5 節陷阱）。

- **區間定義**：00:00–07:59 London time 的 High / Low（M15 收盤棒計算）。
- **區間品質過濾**：區間高度 < `k × ATR(D1)`（例如 k=0.5）才允許交易 —— 亞洲盤已經走大波動的日子，突破延續性差，跳過。
- **進場**：08:00 之後第一根 M15 **收盤價**突破區間上緣 → 做多；跌破下緣 → 做空（用收盤確認，不用 stop order 追穿刺）。
- **每日限制**：每天最多 1 多 + 1 空（或只取第一個訊號），11:00 London time 之後不再進新倉。
- 只讀已收盤棒（`shift=1`），同 repo 慣例。

## 5. 實作陷阱（本策略特有）

- **Server time ≠ London time**：多數 MT5 broker 為 UTC+2/+3（隨美國 DST 切換），且**倫敦與美國 DST 切換日期不同**（每年 3 月/10 月有 1–2 週錯位）。時段窗口寫死 server hour 會在錯位週偏移 1 小時。第一版可接受寫死 + 註記誤差；嚴謹版需做 DST-aware 換算。
- **點差壓測是生死線**：倫敦開盤瞬間 spread 常暴衝。`MaxSpread` 過濾必開，且成本壓測要用**開盤時段的真實點差**，不是全日平均。
- 回測必須 real ticks（開盤跳動劇烈，M15 OHLC 模擬會失真）。

## 6. 出場與風控

- SL：區間對側 或 `ATR × 倍數`，取較近者（區間窄時用區間對側可提高 RR）。
- TP：RR 1.5–2.0（外部回測以 1.5 RR 為佳）。
- 時間出場：當日倫敦收盤（17:00 London time）前強制平倉 → **日內策略，無隔夜風險**，天然避開 swap 與週末跳空。
- 沿用：`MaxSpread`、Friday 提前收倉。

## 7. 第一輪測試計畫

1. **固定參數 baseline**：
   - 商品/週期：`GBPUSD / M15`（主要）、`USDJPY / M15`（次要，repo 既有最強候選）；EURUSD 只當對照組（預期偏弱，若它反而最好要懷疑實作有 bug）。
   - 參數寫死：區間 00:00–08:00 London、收盤突破進場、SL=區間對側、TP RR 1.5、區間品質 k=0.5、17:00 平倉。
   - 期間：2020.06–2026.06，real ticks。
2. 年度拆分 + Forward/OOS + 成本壓測（重點：**開盤時段點差 ×2 情境**），同 `Strategy_Records` 決策標準。
3. 若 baseline 正期望，A/B 只測兩件事：(a) stop order 進場 vs 收盤確認進場；(b) k 值 0.4/0.5/0.6。**不掃時間窗口** —— 時段是這個策略的先驗假設，掃了就變 data mining。

## 8. 可能風險與失效條件（誠實評估）

**結論：這是 repo 目前 backlog 裡先驗機率最高的候選之一，但期望值天花板不高。**

正面：
- 資訊來源（時段 × 訂單流結構）與既有指標型策略**不同質**，組合價值高。
- 邏輯有經濟學基礎（開盤流動性事件），不是指標曲線擬合。
- 參數面積小（區間窗口、k、RR 三個），過擬合面積遠小於 Vegas Tunnel 那類多指標系統。
- 日內平倉，無隔夜/週末風險。

保留意見：
- **極度大眾化**：London breakout 是零售最老的模板之一，容易被 stop hunt（開盤先假突破掃損再反向）。這正是「收盤確認進場」要對抗的，但也會漏掉最快的真突破。
- **證據顯示商品敏感**：EURUSD 弱、GBP 系較好 —— 若回測結果反過來，優先懷疑實作。
- 交易成本占比高（短 SL + 開盤高點差），**淨期望可能被成本吃光** —— 成本壓測是本策略的主要證偽關卡。
- 波動 regime 依賴：低波動年（區間日多、假突破多）預期虧損。

## 9. 進入 `Strategy_Records/` 的條件

- GBPUSD M15 baseline 長樣本正期望，且開盤點差 ×2 壓測後 PF ≥ 1.15。
- 年度拆分無單一年份貢獻全部利潤。
- Forward / OOS 不崩。
- EURUSD 對照組結果與外部證據方向一致（弱），作為實作正確性的 sanity check。

## 相關文件

- 決策標準與研究流程：[../Strategy_Records/MT5_Strategy_Research_Workflow.md](../Strategy_Records/MT5_Strategy_Research_Workflow.md)
- 同為時段型想法：[FX_TimeOfDay_Effect.md](FX_TimeOfDay_Effect.md)、[Gold_Intraday_Seasonality.md](Gold_Intraday_Seasonality.md)

## 外部參考

- [QuantifiedStrategies — London Breakout Strategy: Rules and Backtest](https://www.quantifiedstrategies.com/london-breakout-strategy/)
- [InsiderFinance — Backtest Results Revealed: Is the London Breakout Strategy Worth It?](https://wire.insiderfinance.io/backtest-results-revealed-is-the-london-breakout-strategy-worth-it-0e9df65dd63b)
- [GitHub — london-strategy-backtest（MT5 整合的開源回測框架，可參考實作）](https://github.com/MHZardary/london-strategy-backtest)
