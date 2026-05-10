//+------------------------------------------------------------------+
//|                                        Util_Exchange_Times.mq5 |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_plots 0 // 解決 "no indicator plot defined" 警告

//----程式預設參數
input string str1 = "====系統預設參數====";
input int 本地時區 = 8;
int TimeZone;
input int 倒計時 = 10;
int Countdown;

input string str2 = "====交易所時間表====";
input string 紐約開市時間 = "8:30";
string NewYorkStartTime;
input string 紐約收市時間 = "15:00";
string NewYorkCloseTime;
input string 倫敦開市時間 = "9:30";
string LondonStartTime;
input string 倫敦收市時間 = "16:30";
string LondonCloseTime;
input string 法蘭克福開市時間 = "9:00";
string FrankfurtStartTime;
input string 法蘭克福收市時間 = "16:00";
string FrankfurtCloseTime;
input string 東京開市時間 = "9:00";
string TokyoStartTime;
input string 東京收市時間 = "15:30";
string TokyoCloseTime;
input string 悉尼開市時間 = "9:00";
string SydneyStartTime;
input string 悉尼收市時間 = "17:00";
string SydneyCloseTime;
input string 惠靈頓開市時間 = "9:00";
string WellingtonStartTime;
input string 惠靈頓收市時間 = "17:00";
string WellingtonCloseTime;

input string str3 = "====夏令時間表====";
input string 紐約開始時間 = "2012.3.11 2:00:00";
string NewYorkStartSummer;
input string 紐約結束時間 = "2012.11.4 2:00:00";
string NewYorkCloseSummer;
input string 倫敦開始時間 = "2012.3.25 1:00:00";
string LondonStartSummer;
input string 倫敦結束時間 = "2012.10.28 2:00:00";
string LondonCloseSummer;
input string 法蘭克福開始時間 = "2012.3.25 2:00:00";
string FrankfurtStartSummer;
input string 法蘭克福結束時間 = "2012.10.28 3:00:00";
string FrankfurtCloseSummer;
input string 悉尼開始時間 = "2011.10.2 2:00:00";
string SydneyStartSummer;
input string 悉尼結束時間 = "2012.4.1 3:00:00";
string SydneyCloseSummer;
input string 惠靈頓開始時間 = "2011.9.25 2:00:00";
string WellingtonStartSummer;
input string 惠靈頓結束時間 = "2012.4.1 3:00:00";
string WellingtonCloseSummer;

int Corner = 0; //交易資訊顯示四個角位置
datetime GMT;
color myColor = clrSlateGray;

// 輔助函數：取得時間的日期(日)
int TimeDay(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.day;
}

int OnInit()
  {
   TimeZone = 本地時區;
   Countdown = 倒計時 * 60;
   NewYorkStartTime = 紐約開市時間;
   NewYorkCloseTime = 紐約收市時間;
   LondonStartTime = 倫敦開市時間;
   LondonCloseTime = 倫敦收市時間;
   FrankfurtStartTime = 法蘭克福開市時間;
   FrankfurtCloseTime = 法蘭克福收市時間;
   TokyoStartTime = 東京開市時間;
   TokyoCloseTime = 東京收市時間;
   SydneyStartTime = 悉尼開市時間;
   SydneyCloseTime = 悉尼收市時間;
   WellingtonStartTime = 惠靈頓開市時間;
   WellingtonCloseTime = 惠靈頓收市時間;

   NewYorkStartSummer = 紐約開始時間;
   NewYorkCloseSummer = 紐約結束時間;
   LondonStartSummer = 倫敦開始時間;
   LondonCloseSummer = 倫敦結束時間;
   FrankfurtStartSummer = 法蘭克福開始時間;
   FrankfurtCloseSummer = 法蘭克福結束時間;
   SydneyStartSummer = 悉尼開始時間;
   SydneyCloseSummer = 悉尼結束時間;
   WellingtonStartSummer = 惠靈頓開始時間;
   WellingtonCloseSummer = 惠靈頓結束時間;

   // MT5 指標支援 OnTimer，每秒更新一次時鐘
   EventSetTimer(1);
   
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   int myWindowsHandle = ChartWindowFind();
   ObjectsDeleteAll(0, myWindowsHandle, OBJ_LABEL);
  }

void OnTimer()
  {
   iMain();
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // 僅在有新 Tick 時也更新一下
   iMain();
   return(rates_total);
  }

void iDisplayInfo(string LableName, string LableDoc, int CornerPos, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   int myWindowsHandle = ChartWindowFind();
   if(myWindowsHandle < 0) myWindowsHandle = 0;

   ObjectCreate(0, LableName, OBJ_LABEL, myWindowsHandle, 0, 0);
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   if(DocStyle != "") ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
   ObjectSetInteger(0, LableName, OBJPROP_CORNER, CornerPos);
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
  }

void iMain()
  {
   int myWindowsHandle = ChartWindowFind();
   
   GMT = TimeLocal() - TimeZone * 3600;
   iDisplayInfo("GMT&LocalTime", "GMT "+TimeToString(GMT,TIME_SECONDS)+"  伺服器時間 "+TimeToString(TimeCurrent(),TIME_SECONDS)+"  本地時間 "+TimeToString(TimeLocal(),TIME_SECONDS), Corner, 230, 1, 10, "", clrSlateGray);
   
   //惠靈頓
   datetime myWellington = GMT + 12 * 3600;
   if (TimeDay(StringToTime(WellingtonStartTime)) < TimeDay(myWellington)) //換算跨日
     {
      WellingtonStartTime = TimeToString(StringToTime(WellingtonStartTime) + 86400);
      WellingtonCloseTime = TimeToString(StringToTime(WellingtonCloseTime) + 86400);
     }
   if (myWellington > StringToTime(WellingtonStartSummer) && myWellington < StringToTime(WellingtonCloseSummer)) myWellington = myWellington + 3600; //夏令時+1
   myColor = clrSlateGray;
   iDisplayInfo("WellingtonOpenCountdown", "休市", Corner, 80, 60, 8, "", myColor);
   if ((StringToTime(WellingtonStartTime) - myWellington) < Countdown && (StringToTime(WellingtonStartTime) - myWellington) > 0)
     {
      myColor = clrOrangeRed;
      iDisplayInfo("WellingtonOpenCountdown", "距開市" + IntegerToString((int)((StringToTime(WellingtonStartTime) - myWellington) / 60 + 1)) + "分鐘", Corner, 70, 60, 8, "", myColor);
     }
   if (myWellington > StringToTime(WellingtonStartTime) && myWellington < StringToTime(WellingtonCloseTime))
     {
      myColor = clrForestGreen;
      iDisplayInfo("WellingtonOpenCountdown", "正在交易", Corner, 80, 60, 8, "", myColor);
     }
   if ((StringToTime(WellingtonCloseTime) - myWellington) < Countdown && (StringToTime(WellingtonCloseTime) - myWellington) > 0)
     {
      myColor = clrRed;
      iDisplayInfo("WellingtonOpenCountdown", "距收市" + IntegerToString((int)((StringToTime(WellingtonCloseTime) - myWellington) / 60 + 1)) + "分鐘", Corner, 70, 60, 8, "", myColor);
     }
   iDisplayInfo("WellingtonTime", "惠靈頓" + TimeToString(myWellington, TIME_SECONDS), Corner, 50, 20, 10, "", myColor);
   iDisplayInfo("WellingtonDate", TimeToString(myWellington, TIME_DATE), Corner, 70, 40, 10, "", myColor);
   
   //悉尼
   datetime mySydney = GMT + 10 * 3600;
   if (TimeDay(StringToTime(SydneyStartTime)) < TimeDay(mySydney)) //換算跨日
     {
      SydneyStartTime = TimeToString(StringToTime(SydneyStartTime) + 86400);
      SydneyCloseTime = TimeToString(StringToTime(SydneyCloseTime) + 86400);
     }
   if (mySydney > StringToTime(SydneyStartSummer) && mySydney < StringToTime(SydneyCloseSummer)) mySydney = mySydney + 3600; //夏令時+1
   myColor = clrSlateGray;
   iDisplayInfo("SydneyOpenCountdown", "休市", Corner, 180, 60, 8, "", myColor);
   if ((StringToTime(SydneyStartTime) - mySydney) < Countdown && (StringToTime(SydneyStartTime) - mySydney) > 0)
     {
      myColor = clrOrangeRed;
      iDisplayInfo("SydneyOpenCountdown", "距開市" + IntegerToString((int)((StringToTime(SydneyStartTime) - mySydney) / 60 + 1)) + "分鐘", Corner, 180, 60, 8, "", myColor);
     }
   if (mySydney > StringToTime(SydneyStartTime) && mySydney < StringToTime(SydneyCloseTime))
     {
      myColor = clrForestGreen;
      iDisplayInfo("SydneyOpenCountdown", "正在交易", Corner, 180, 60, 8, "", myColor);
     }
   if ((StringToTime(SydneyCloseTime) - mySydney) < Countdown && (StringToTime(SydneyCloseTime) - mySydney) > 0)
     {
      myColor = clrRed;
      iDisplayInfo("SydneyOpenCountdown", "距收市" + IntegerToString((int)((StringToTime(SydneyCloseTime) - mySydney) / 60 + 1)) + "分鐘", Corner, 180, 60, 8, "", myColor);
     }
   iDisplayInfo("SydneyTime", "悉尼" + TimeToString(mySydney, TIME_SECONDS), Corner, 170, 20, 10, "", myColor);
   iDisplayInfo("SydneyDate", TimeToString(mySydney, TIME_DATE), Corner, 180, 40, 10, "", myColor);
   
   //東京
   datetime myTokyo = GMT + 9 * 3600;
   if (TimeDay(StringToTime(TokyoStartTime)) < TimeDay(myTokyo)) //換算跨日
     {
      TokyoStartTime = TimeToString(StringToTime(TokyoStartTime) + 86400);
      TokyoCloseTime = TimeToString(StringToTime(TokyoCloseTime) + 86400);
     }
   myColor = clrSlateGray;
   iDisplayInfo("TokyoOpenCountdown", "休市", Corner, 280, 60, 8, "", myColor);
   if ((StringToTime(TokyoStartTime) - myTokyo) < Countdown && (StringToTime(TokyoStartTime) - myTokyo) > 0)
     {
      myColor = clrOrangeRed;
      iDisplayInfo("TokyoOpenCountdown", "距開市" + IntegerToString((int)((StringToTime(TokyoStartTime) - myTokyo) / 60 + 1)) + "分鐘", Corner, 280, 60, 8, "", myColor);
     }
   if (myTokyo > StringToTime(TokyoStartTime) && myTokyo < StringToTime(TokyoCloseTime))
     {
      myColor = clrForestGreen;
      iDisplayInfo("TokyoOpenCountdown", "正在交易", Corner, 280, 60, 8, "", myColor);
     }
   if ((StringToTime(TokyoCloseTime) - myTokyo) < Countdown && (StringToTime(TokyoCloseTime) - myTokyo) > 0)
     {
      myColor = clrRed;
      iDisplayInfo("TokyoOpenCountdown", "距收市" + IntegerToString((int)((StringToTime(TokyoCloseTime) - myTokyo) / 60 + 1)) + "分鐘", Corner, 280, 60, 8, "", myColor);
     }
   iDisplayInfo("TokyoTime", "東京" + TimeToString(myTokyo, TIME_SECONDS), Corner, 270, 20, 10, "", myColor);
   iDisplayInfo("TokyoDate", TimeToString(myTokyo, TIME_DATE), Corner, 280, 40, 10, "", myColor);
   
   //法蘭克福
   datetime myFrankfurt = GMT + 1 * 3600;
   if (TimeDay(StringToTime(FrankfurtStartTime)) < TimeDay(myFrankfurt)) //換算跨日
     {
      FrankfurtStartTime = TimeToString(StringToTime(FrankfurtStartTime) + 86400);
      FrankfurtCloseTime = TimeToString(StringToTime(FrankfurtCloseTime) + 86400);
     }
   if (myFrankfurt > StringToTime(FrankfurtStartSummer) && myFrankfurt < StringToTime(FrankfurtCloseSummer)) myFrankfurt = myFrankfurt + 3600; //夏令時+1
   myColor = clrSlateGray;
   iDisplayInfo("FrankfurtOpenCountdown", "休市", Corner, 400, 60, 8, "", myColor);
   if ((StringToTime(FrankfurtStartTime) - myFrankfurt) < Countdown && (StringToTime(FrankfurtStartTime) - myFrankfurt) > 0)
     {
      myColor = clrOrangeRed;
      iDisplayInfo("FrankfurtOpenCountdown", "距開市" + IntegerToString((int)((StringToTime(FrankfurtStartTime) - myFrankfurt) / 60 + 1)) + "分鐘", Corner, 400, 60, 8, "", myColor);
     }
   if (myFrankfurt > StringToTime(FrankfurtStartTime) && myFrankfurt < StringToTime(FrankfurtCloseTime))
     {
      myColor = clrForestGreen;
      iDisplayInfo("FrankfurtOpenCountdown", "正在交易", Corner, 410, 60, 8, "", myColor);
     }
   if ((StringToTime(FrankfurtCloseTime) - myFrankfurt) < Countdown && (StringToTime(FrankfurtCloseTime) - myFrankfurt) > 0)
     {
      myColor = clrRed;
      iDisplayInfo("FrankfurtOpenCountdown", "距收市" + IntegerToString((int)((StringToTime(FrankfurtCloseTime) - myFrankfurt) / 60 + 1)) + "分鐘", Corner, 400, 60, 8, "", myColor);
     }
   iDisplayInfo("FrankfurtTime", "法蘭克福" + TimeToString(myFrankfurt, TIME_SECONDS), Corner, 370, 20, 10, "", myColor);
   iDisplayInfo("FrankfurtDate", TimeToString(myFrankfurt, TIME_DATE), Corner, 400, 40, 10, "", myColor);
   
   //倫敦
   datetime myLondon = GMT + 0 * 3600;
   if (TimeDay(StringToTime(LondonStartTime)) < TimeDay(myLondon)) //換算跨日
     {
      LondonStartTime = TimeToString(StringToTime(LondonStartTime) + 86400);
      LondonCloseTime = TimeToString(StringToTime(LondonCloseTime) + 86400);
     }
   if (myLondon > StringToTime(LondonStartSummer) && myLondon < StringToTime(LondonCloseSummer)) myLondon = myLondon + 3600; //夏令時+1
   myColor = clrSlateGray;
   iDisplayInfo("LondonOpenCountdown", "休市", Corner, 530, 60, 8, "", myColor);
   if ((StringToTime(LondonStartTime) - myLondon) < Countdown && (StringToTime(LondonStartTime) - myLondon) > 0)
     {
      myColor = clrOrangeRed;
      iDisplayInfo("LondonOpenCountdown", "距開市" + IntegerToString((int)((StringToTime(LondonStartTime) - myLondon) / 60 + 1)) + "分鐘", Corner, 510, 60, 8, "", myColor);
     }
   if (myLondon > StringToTime(LondonStartTime) && myLondon < StringToTime(LondonCloseTime))
     {
      myColor = clrForestGreen;
      iDisplayInfo("LondonOpenCountdown", "正在交易", Corner, 510, 60, 8, "", myColor);
     }
   if ((StringToTime(LondonCloseTime) - myLondon) < Countdown && (StringToTime(LondonCloseTime) - myLondon) > 0)
     {
      myColor = clrRed;
      iDisplayInfo("LondonOpenCountdown", "距收市" + IntegerToString((int)((StringToTime(LondonCloseTime) - myLondon) / 60 + 1)) + "分鐘", Corner, 510, 60, 8, "", myColor);
     }
   iDisplayInfo("LondonTime", "倫敦" + TimeToString(myLondon, TIME_SECONDS), Corner, 500, 20, 10, "", myColor);
   iDisplayInfo("LondonDate", TimeToString(myLondon, TIME_DATE), Corner, 510, 40, 10, "", myColor);
   
   //紐約
   datetime myNewYork = GMT + (-5) * 3600;
   if (TimeDay(StringToTime(NewYorkStartTime)) < TimeDay(myNewYork)) //換算跨日
     {
      NewYorkStartTime = TimeToString(StringToTime(NewYorkStartTime) + 86400);
      NewYorkCloseTime = TimeToString(StringToTime(NewYorkCloseTime) + 86400);
     }
   if (myNewYork > StringToTime(NewYorkStartSummer) && myNewYork < StringToTime(NewYorkCloseSummer)) myNewYork = myNewYork + 3600; //夏令時+1
   myColor = clrSlateGray;
   iDisplayInfo("NewYorkOpenCountdown", "休市", Corner, 630, 60, 8, "", myColor);
   if ((StringToTime(NewYorkStartTime) - myNewYork) < Countdown && (StringToTime(NewYorkStartTime) - myNewYork) > 0)
     {
      myColor = clrOrangeRed;
      iDisplayInfo("NewYorkOpenCountdown", "距開市" + IntegerToString((int)((StringToTime(NewYorkStartTime) - myNewYork) / 60 + 1)) + "分鐘", Corner, 605, 60, 8, "", myColor);
     }
   if (myNewYork > StringToTime(NewYorkStartTime) && myNewYork < StringToTime(NewYorkCloseTime))
     {
      myColor = clrForestGreen;
      iDisplayInfo("NewYorkOpenCountdown", "正在交易", Corner, 620, 60, 8, "", myColor);
     }
   if ((StringToTime(NewYorkCloseTime) - myNewYork) < Countdown && (StringToTime(NewYorkCloseTime) - myNewYork) > 0)
     {
      myColor = clrRed;
      iDisplayInfo("NewYorkOpenCountdown", "距收市" + IntegerToString((int)((StringToTime(NewYorkCloseTime) - myNewYork) / 60 + 1)) + "分鐘", Corner, 605, 60, 8, "", myColor);
     }
   iDisplayInfo("NewYorkTime", "紐約" + TimeToString(myNewYork, TIME_SECONDS), Corner, 600, 20, 10, "", myColor);
   iDisplayInfo("NewYorkDate", TimeToString(myNewYork, TIME_DATE), Corner, 610, 40, 10, "", myColor);
  }
