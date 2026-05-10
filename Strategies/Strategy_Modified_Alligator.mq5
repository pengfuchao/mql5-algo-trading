//+------------------------------------------------------------------+
//|                                  Strategy_Modified_Alligator.mq5 |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input int StopLoss = 40;
input int TakeProfit = 0;
input double MaxRisk = 30;   // 資金風險 1 = 1%
input double Filter = 0.35;  // Force指標過濾參數
input ulong MagicNumber = 5555; // 變更 Magic Number 以區別

CTrade trade;
int alligatorHandle;
int forceHandle;

double Alligator_jaw, Alligator_teeth, Alligator_lips;
double Force3;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   
   alligatorHandle = iAlligator(Symbol(), PERIOD_M30, 8, 0, 5, 0, 3, 0, MODE_EMA, PRICE_WEIGHTED);
   forceHandle = iForce(Symbol(), PERIOD_M30, 3, MODE_EMA, VOLUME_TICK);
   
   if(alligatorHandle == INVALID_HANDLE || forceHandle == INVALID_HANDLE)
     {
      Print("無法載入指標 Handle！");
      return(INIT_FAILED);
     }
     
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(alligatorHandle != INVALID_HANDLE) IndicatorRelease(alligatorHandle);
   if(forceHandle != INVALID_HANDLE) IndicatorRelease(forceHandle);
   ObjectsDeleteAll(0, -1, OBJ_LABEL);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // 週五20點停止交易，盈利訂單平倉
   MqlDateTime dt;
   TimeCurrent(dt);
   
   if (dt.day_of_week == 5 && dt.hour >= 20)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            if(PositionGetDouble(POSITION_PROFIT) > 0) trade.PositionClose(ticket);
           }
        }
      return;
     }
     
   string signal = ReturnMarketInfomation();
   
   SetLable("時間欄", "星期" + IntegerToString(dt.day_of_week) + " 市場時間：" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), 200, 0, 9, "Verdana", clrRed);
   
   double totalProfit = 0;
   int myPositions = 0;
   datetime lastOpenTime = 0;
   long lastType = -1;
   ulong lastTicket = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         myPositions++;
         totalProfit += PositionGetDouble(POSITION_PROFIT);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > lastOpenTime)
           {
            lastOpenTime = openTime;
            lastType = PositionGetInteger(POSITION_TYPE);
            lastTicket = ticket;
           }
        }
     }
     
   SetLable("資訊欄", "市場訊號:" + signal + " 當前訂單總盈虧:" + DoubleToString(totalProfit, 2), 5, 20, 10, "Verdana", clrBlue);
   
   // 新開倉訂單時間不足一個時間週期(M30)，不做任何操作
   if (myPositions > 0 && TimeCurrent() - lastOpenTime <= PeriodSeconds(PERIOD_M30)) return;
   
   double sl_buy = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - StopLoss * _Point;
   double tp_buy = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + TakeProfit * _Point;
   double sl_sell = SymbolInfoDouble(Symbol(), SYMBOL_BID) + StopLoss * _Point;
   double tp_sell = SymbolInfoDouble(Symbol(), SYMBOL_BID) - TakeProfit * _Point;
   
   if (StopLoss == 0) { sl_buy = 0; sl_sell = 0; }
   if (TakeProfit == 0) { tp_buy = 0; tp_sell = 0; }
   
   // 開倉操作
   if (myPositions == 0)
     {
      double tradeLots = LotsOptimized(MaxRisk);
      if(tradeLots > 0)
        {
         if (signal == "Buy")  trade.Buy(tradeLots, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_ASK), sl_buy, tp_buy, "Modified Alligator Buy");
         if (signal == "Sell") trade.Sell(tradeLots, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), sl_sell, tp_sell, "Modified Alligator Sell");
        }
     }
     
   // 平倉操作
   if (myPositions == 1) // 原版限制 OrdersTotal()==1 時才做平倉邏輯
     {
      if (totalProfit > 0) // 止盈操作
        {
         if (lastType == POSITION_TYPE_BUY && signal == "DownCross") trade.PositionClose(lastTicket);
         if (lastType == POSITION_TYPE_SELL && signal == "UpCross") trade.PositionClose(lastTicket);
        }
      if (totalProfit < 0) // 止損操作
        {
         if (lastType == POSITION_TYPE_BUY && Alligator_lips < Alligator_jaw) trade.PositionClose(lastTicket);
         if (lastType == POSITION_TYPE_SELL && Alligator_lips > Alligator_jaw) trade.PositionClose(lastTicket);
        }
     }
  }

double LotsOptimized(double RiskValue)
  {
   double marginRequired = 1000;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), 1.0, SymbolInfoDouble(Symbol(), SYMBOL_ASK), marginRequired)) marginRequired = 1000;
   if(marginRequired == 0) marginRequired = 1000;
   
   double iLots = NormalizeDouble((AccountInfoDouble(ACCOUNT_BALANCE) * RiskValue / 100) / marginRequired, 2);
   if (iLots < 0.01) { iLots = 0; Print("保證金餘額不足"); }
   
   HistorySelect(0, TimeCurrent());
   int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
         if(HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0) iLots = 0.01;
         break;
        }
     }
   return (iLots);
  }

string ReturnMarketInfomation()
  {
   string MktInfo = "N/A";
   
   double jaw[], teeth[], lips[];
   if(CopyBuffer(alligatorHandle, 0, 0, 2, jaw) < 2) return MktInfo;
   if(CopyBuffer(alligatorHandle, 1, 0, 2, teeth) < 2) return MktInfo;
   if(CopyBuffer(alligatorHandle, 2, 0, 2, lips) < 2) return MktInfo;
   
   ArraySetAsSeries(jaw, true);
   ArraySetAsSeries(teeth, true);
   ArraySetAsSeries(lips, true);
   
   Alligator_jaw = jaw[0];
   Alligator_teeth = teeth[0];
   Alligator_lips = lips[0];
   
   double Alligator_jaw_1 = jaw[1];
   double Alligator_teeth_1 = teeth[1];
   double Alligator_lips_1 = lips[1];
   
   double force[1];
   if(CopyBuffer(forceHandle, 0, 0, 1, force) < 1) return MktInfo;
   Force3 = force[0];
   
   if (Alligator_lips > Alligator_teeth && Alligator_lips_1 <= Alligator_teeth_1) MktInfo = "UpCross";
   if (Alligator_lips < Alligator_teeth && Alligator_lips_1 >= Alligator_teeth_1) MktInfo = "DownCross";
   
   if (Alligator_lips > Alligator_teeth && Alligator_teeth > Alligator_jaw) MktInfo = "Rise";
   if (Alligator_lips < Alligator_teeth && Alligator_teeth < Alligator_jaw) MktInfo = "Fall";
   
   if (Force3 > Filter && MktInfo == "Rise") MktInfo = "Buy";
   if (Force3 < -Filter && MktInfo == "Fall") MktInfo = "Sell";
   
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
