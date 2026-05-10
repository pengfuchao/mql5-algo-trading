//+------------------------------------------------------------------+
//|                                         Util_Time_Validation.mq5 |
//+------------------------------------------------------------------+
/*
函    數：有效時間段
輸入參數：string myStartTime:開始時間，標準格式為hh:mm
          string myEndTime:結束時間，標準格式為hh:mm
          bool myServerTime:true為伺服器時間, false為計算機時間
輸出參數：true:有效  false:無效
算    法：判斷當前時間是否在指定的交易時間段內
*/
bool iValidTime(string myStartTime,string myEndTime,bool myServerTime)
   {
      bool myValue=false;
      datetime myST=StringToTime(myStartTime);
      datetime myET=StringToTime(myEndTime);
      if (myST>myET) myET=myET+1440*60;
      if (TimeCurrent()>myST && TimeCurrent()<myET && myServerTime==true)//伺服器時間
         {
            myValue=true;
         }
      if (TimeLocal()>myST && TimeLocal()<myET && myServerTime==false)//計算機時間
         {
            myValue=true;
         }
      if (myST==myET) myValue=true;
      return(myValue);
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Dummy event handler to prevent compilation error
  }

