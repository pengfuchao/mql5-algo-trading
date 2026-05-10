//+------------------------------------------------------------------+
//|                                     Strategy_MACD_Martingale.mq5 |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input double Init_Lots = 0.01;      // 初始開倉量
input double Profit_Rate = 34;      // 利潤率，用於計算新的開倉量
input double Max_Bet_Lots = 0.4;    // 最大允許開倉量
input double LostRate = 2;          // 虧損加倍率
input ulong  MagicNumber = 3333;

int Order_Total = 50;   // 最大訂單數量
int Bet_Order = 50;     // 允許的加倍訂單數量
bool LotsDouble = true; // 是否允許虧損加倍

int iBet_Order = 0;     // 加倍訂單計數器變數
double perProfit = 0;   // 每批訂單總盈虧變數
double iLots;           // 追加訂單開倉量變數
double Init_Balance;    // 帳戶初始餘額變數
double xMax_Bet_Lots;   // 最大浮動開倉量變數

CTrade trade;
int macdHandle;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   iLots = Init_Lots;
   xMax_Bet_Lots = Max_Bet_Lots;
   Init_Balance = AccountInfoDouble(ACCOUNT_BALANCE); // 取初始帳戶餘額
   
   macdHandle = iMACD(Symbol(), PERIOD_CURRENT, 10, 60, 1, PRICE_CLOSE);
   if(macdHandle == INVALID_HANDLE)
     {
      Print("無法載入 MACD 指標！");
      return(INIT_FAILED);
     }
     
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
   ObjectsDeleteAll(0, -1, OBJ_LABEL);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // 提取市場訊號
   string mktSignal = ReturnMarketInfomation();
   
   // 顯示市場訊息
   MqlDateTime dt;
   TimeCurrent(dt);
   SetLable("時間欄", "星期" + IntegerToString(dt.day_of_week) + " 市場時間 " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), 200, 0, 9, "Verdana", clrRed);
   SetLable("資訊欄1", "市場信號:" + mktSignal + " 最大開倉量:" + DoubleToString(xMax_Bet_Lots, 2), 5, 60, 10, "Verdana", clrBlue);
   SetLable("資訊欄2", "初始餘額:" + DoubleToString(Init_Balance, 2) + " 當前餘額:" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), 5, 20, 10, "Verdana", clrBlue);
   SetLable("資訊欄3", "最低開倉量:" + DoubleToString(NewLots(), 2) + " 浮動開倉量:" + DoubleToString(iLots, 2), 5, 40, 10, "Verdana", clrBlue);
   
   int totalPositions = PositionsTotal();
   int myPositions = 0;
   long lastPosType = -1;
   datetime lastOpenTime = 0;
   double lastOpenPrice = 0;
   
   for(int i = 0; i < totalPositions; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         myPositions++;
         long type = PositionGetInteger(POSITION_TYPE);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > lastOpenTime)
           {
            lastOpenTime = openTime;
            lastPosType = type;
            lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
           }
        }
     }
   
   /// 新開倉
   if(myPositions == 0)
     {
      if(perProfit < 0 && LotsDouble == true) iLots = iLots * LostRate; // 虧損加倍
      if(iLots > xMax_Bet_Lots) iLots = xMax_Bet_Lots;                  // 限制最大開倉量
      
      Open_New_Order(iLots, mktSignal);
      perProfit = 0; // 前一批訂單盈利變數清0
     }
     
   /// 處理已有訂單
   if(myPositions > 0)
     {
      // 新開倉訂單時間不足一個時間週期，不做任何操作返回
      if(TimeCurrent() - lastOpenTime <= PeriodSeconds(PERIOD_CURRENT)) return;
      
      // 追加盈利訂單
      double iiLots = iLots;
      if(iBet_Order > Bet_Order - 1) iiLots = NewLots(); // 如果超過加倍數量，交易量恢復
      
      if(lastPosType == POSITION_TYPE_BUY && mktSignal == "Buy" && myPositions <= Order_Total && SymbolInfoDouble(Symbol(), SYMBOL_ASK) > lastOpenPrice)
        {
         if(trade.Buy(iiLots, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_ASK), 0, 0, "MACD Martingale Add Buy"))
           {
            Draw_Mark(trade.ResultOrder(), 0);
            iBet_Order++;
           }
        }
      if(lastPosType == POSITION_TYPE_SELL && mktSignal == "Sell" && myPositions <= Order_Total && SymbolInfoDouble(Symbol(), SYMBOL_BID) < lastOpenPrice)
        {
         if(trade.Sell(iiLots, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, "MACD Martingale Add Sell"))
           {
            Draw_Mark(trade.ResultOrder(), 1);
            iBet_Order++;
           }
        }
        
      // 止損平倉。如果出現反向訊號，平掉所有訂單
      if(lastPosType == POSITION_TYPE_BUY && mktSignal == "Sell")
        {
         CloseAllPositions(POSITION_TYPE_BUY);
         if(perProfit >= 0) iLots = NewLots();
         iBet_Order = 0;
        }
      if(lastPosType == POSITION_TYPE_SELL && mktSignal == "Buy")
        {
         CloseAllPositions(POSITION_TYPE_SELL);
         if(perProfit >= 0) iLots = NewLots();
         iBet_Order = 0;
        }
     }
  }

void CloseAllPositions(long targetType)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         if(PositionGetInteger(POSITION_TYPE) == targetType)
           {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(trade.PositionClose(ticket))
              {
               perProfit += profit;
              }
           }
        }
     }
  }

double NewLots()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double xRate = ((balance - Init_Balance) / Init_Balance) / (Profit_Rate / 100);
   double xLots = NormalizeDouble(Init_Lots * xRate, 2);
   
   if(xLots < 0.01) xLots = 0.01;
   if(xRate > 1) xMax_Bet_Lots = Max_Bet_Lots * xRate;
   
   return(xLots);
  }

void Open_New_Order(double MyLots, string signal)
  {
   if(signal == "Buy")
     {
      if(trade.Buy(MyLots, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_ASK), 0, 0, "MACD Buy"))
         Draw_Mark(trade.ResultOrder(), 0);
     }
   if(signal == "Sell")
     {
      if(trade.Sell(MyLots, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, "MACD Sell"))
         Draw_Mark(trade.ResultOrder(), 1);
     }
  }

string ReturnMarketInfomation()
  {
   string MktInfo = "N/A";
   double macdSignal[]; // 需要索引 0 和 10
   if(CopyBuffer(macdHandle, 1, 0, 11, macdSignal) < 11) return MktInfo; // 緩衝區 1 為 SIGNAL LINE
   ArraySetAsSeries(macdSignal, true);
   
   double MACD_0 = macdSignal[0];
   double MACD_2 = macdSignal[10]; // MT4的索引 10 對應到這裡
   
   double closeArray[1];
   if(CopyClose(Symbol(), PERIOD_CURRENT, 0, 1, closeArray) < 1) return MktInfo;
   double price_0 = closeArray[0];
   
   double highArray[], lowArray[];
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 0, 3, highArray) < 3) return MktInfo;
   if(CopyLow(Symbol(), PERIOD_CURRENT, 0, 3, lowArray) < 3) return MktInfo;
   ArraySetAsSeries(highArray, true);
   ArraySetAsSeries(lowArray, true);
   
   double price_high_2 = highArray[2];
   double price_low_2 = lowArray[2];
   
   if(MACD_0 > (MACD_2 + 0.00003) && price_0 > price_high_2)
      MktInfo = "Sell";
      
   if(MACD_0 < (MACD_2 - 0.00003) && price_0 < price_low_2)
      MktInfo = "Buy";
      
   return(MktInfo);
  }

void SetLable(string LableName, string LableDoc, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   ObjectCreate(0, LableName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
  }

void Draw_Mark(ulong MyTicket, int type)
  {
   if(MyTicket == 0) return;
   string ArrowMyTicket = "Arrow:" + IntegerToString(MyTicket);
   int ArrowValue = (type == 0) ? 221 : 222;
   color ArrowColor = (type == 0) ? clrGreen : clrRed;
   
   double openPrice = (type == 0) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   ObjectCreate(0, ArrowMyTicket, OBJ_ARROW, 0, TimeCurrent(), openPrice);
   ObjectSetInteger(0, ArrowMyTicket, OBJPROP_ARROWCODE, ArrowValue);
   ObjectSetInteger(0, ArrowMyTicket, OBJPROP_COLOR, ArrowColor);
  }
