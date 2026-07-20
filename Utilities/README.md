# Utilities (實用工具與模組)

本資料夾存放大量在開發 MT5 策略或進行日常交易時所需的輔助工具、腳本與模組庫。涵蓋了訂單操作、圖表繪圖、資金管理與時間控制等常用功能。

> **整合注意事項**：目前多數檔案是可獨立編譯的 `.mq5` script、indicator 或程式片段，部分檔案包含 `OnStart()`、`OnInit()` 或 `OnCalculate()` event handler。它們不能直接當成通用 include library 使用；若要由 EA 重用，應先抽取純函數至 `.mqh`，移除衝突的 event handler，並處理全域變數與 `CTrade` 物件命名。

## 檔案說明

以下為本資料夾內各個實用工具檔案的功能講解：

### 研究統計腳本 (Research Statistics)
*   **`Script_Weekend_Gap_Stats.mq5`**: Weekend Gap Fade Phase 0 統計掃描腳本。逐一掃描指定 symbols 的 M15 歷史資料，以週五最後一根 M15 與其後第一根 bar 定義 weekend gap，輸出每週 gap、24/48h 是否回補、bars to fill、MAE 與 ATR(D1) 正規化欄位到 `MQL5/Files/` CSV，並在 Experts log 印 gap-size bucket summary。
*   **`Script_FX_TimeOfDay_Cost_Check.mq5`**: FX Time-of-Day Effect Phase 0 成本關卡腳本。不開倉，只抽樣目前 symbol bid/ask spread，將輸入的 round-turn commission 與 slippage 換算成 pips，輸出 one-side equivalent cost、GO/BORDERLINE/KILL 判定與 CSV 證據列。
*   **`Script_XAUUSD_Session_Spread_Calibration.mq5`**: Gold Intraday Seasonality preset 校準腳本。不開倉，掃描 M1 歷史的 `MqlRates.spread`（單位 points），依 server hour 分組輸出 avg / median / p90 / p95 / max，一次同時校準 MAIN 與 CTRL-1/2/3 四個窗口，並給出建議 `InpMaxSpreadPts`（median × 安全倍數）與等價報價貨幣/oz 點差、CSV 證據。另會回報**實際取得的歷史區間與覆蓋率**：`CopyRates` 對缺資料的區間只會安靜回傳現有部分，因此長區間回測前應先用本腳本確認終端真的有那段歷史。**單位是 points，與 `Strategy_Time_Window.mq5` 一致；不可與 `Script_FX_TimeOfDay_Cost_Check.mq5` 的 pips 輸出混用。**

### 訂單與部位管理 (Order & Position Management)
*   **`Util_Open_Order.mq5`**: 開倉下單的標準封裝工具，簡化 `CTrade` 的調用。
*   **`Util_Close_Order.mq5`**: 單一訂單平倉工具。
*   **`Util_Close_All.mq5`**: 一鍵平倉腳本，用於快速關閉所有開啟的部位。
*   **`Util_Iterate_Orders.mq5`**: 遍歷訂單迴圈的範本，用於掃描並處理當前帳戶內的所有活動訂單。
*   **`Util_Position_Status.mq5`**: 獲取並檢查當前商品持倉狀態（多空方向、口數、盈虧等）的工具。
*   **`Util_Trailing_Stop.mq5`**: 移動止損 (Trailing Stop) 的核心邏輯工具。
*   **`Util_Order_Flow_Control.mq5`**: 訂單流程控制工具，用於限制頻繁下單或控制整體交易頻率。

### 資金管理與計算 (Money Management & Calculation)
*   **`Util_Money_Management.mq5`**: 基礎資金管理模組，可依據帳戶餘額或風險比例計算合適的下單手數。
*   **`Util_Turtle_Position_Calc.mq5`**: 專為海龜交易法設計的倉位規模計算工具，基於 ATR 波動率計算 N 值與手數。
*   **`Util_Calc_High_Low_Range.mq5`**: 計算特定週期內 K 線高低點範圍的工具。
*   **`Util_Extract_Numbers.mq5`**: 從字串或特定數據格式中提取數值資料的正則/字串解析工具。

### 圖表與視覺化物件 (Chart Objects & Visualization)
*   **`Util_Chart_Objects.mq5`**: 處理 MT5 圖表物件 (ObjectCreate 等) 的基礎工具集合。
*   **`Util_Draw_Line.mq5`**: 在圖表上自動繪製趨勢線或線段的工具。
*   **`Util_Horizontal_Vertical_Line.mq5`**: 在圖表上快速繪製水平線 (例如支撐壓力位) 與垂直線的工具。
*   **`Util_Draw_Symbol.mq5`**: 繪製特定箭頭或圖形符號的工具 (常用於標記進出場點)。
*   **`Util_Doji_Line.mq5`**: 自動標註圖表上十字星 (Doji) K 線的視覺化工具。
*   **`Util_Object_Color.mq5`**: 管理或動態更改圖表物件顏色的腳本。
*   **`Util_Display_Text.mq5`**: 在圖表特定位置顯示自定義文字標籤的工具。
*   **`Util_Display_Market_Info.mq5`**: 在圖表畫面角落顯示即時市場資訊（點差、保證金要求等）的面板工具。
*   **`Util_Popup_Message.mq5`**: 發送彈出視窗警告 (Alert) 或推送通知的模組。
*   **`Util_Visual_History.mq5` / `Util_History_Review.mq5`**: 將過去的歷史交易紀錄繪製到圖表上，方便覆盤與視覺化檢討的工具。

### 訊號與市場狀態判斷 (Signal & Market Status)
*   **`Util_Candle_Pattern.mq5`**: 基礎 K 線型態 (Candlestick Patterns) 識別工具。
*   **`Util_Cross_Signal.mq5`**: 判斷兩條線（如雙均線或指標）是否發生黃金交叉/死亡交叉的邏輯模組。

### 時間控制 (Time Management)
*   **`Util_Exchange_Times.mq5`**: 處理不同交易所時區轉換與顯示各國開盤時間的工具。
*   **`Util_Time_Validation.mq5`**: 時間驗證工具，用於限制 EA 只能在特定時段內進行交易。
*   **`Util_Timer_Trading.mq5`**: 基於 `OnTimer` 事件進行定時交易與週期性檢查的控制腳本。
