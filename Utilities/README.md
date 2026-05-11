# Utilities (實用工具與模組)

本資料夾存放大量在開發 MT5 策略或進行日常交易時所需的輔助工具、腳本與模組庫。涵蓋了訂單操作、圖表繪圖、資金管理與時間控制等常用功能。

## 檔案說明

以下為本資料夾內各個實用工具檔案的功能講解：

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
