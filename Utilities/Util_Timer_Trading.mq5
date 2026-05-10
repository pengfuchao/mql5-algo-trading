//+------------------------------------------------------------------+
//|                                           Util_Timer_Trading.mq5 |
//+------------------------------------------------------------------+
/* 
函數說明：交易時間控制
參數說明：開始自動交易時、分和停止交易時、分
返回值：true為自動交易有效、false為自動交易無效
備註：時分參數均為系統時間
*/
bool EA_Valid = false; // 定義並初始化布爾變量 EA_Valid 為 false

bool iTimeControl(int myStartHour, int myStartMinute, int myStopHour, int myStopMinute)
{
    MqlDateTime dt;
    TimeCurrent(dt); // 獲取當前系統時間
    
    int currentHour = dt.hour;
    int currentMinute = dt.min;
    
    if (currentHour == 0 && currentMinute == 0) EA_Valid = false; // 如果當前時間是午夜（0點0分），將 EA_Valid 設置為 false
    
    if (currentHour == myStopHour && currentMinute == myStopMinute + 1) // 如果當前時間是停止時間的下一分鐘，將 EA_Valid 設置為 false
    {
        EA_Valid = false;
    }
    
    if (currentHour == myStartHour && currentMinute == myStartMinute) // 如果當前時間是開始時間，將 EA_Valid 設置為 true
    {
        EA_Valid = true;
    }
    
    return (EA_Valid); // 返回 EA_Valid 的值
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  }
