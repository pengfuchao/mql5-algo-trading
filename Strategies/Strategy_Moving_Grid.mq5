//+------------------------------------------------------------------+
//|                                         Strategy_Moving_Grid.mq5 |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input string str1 = "====系統預設參數====";
input double 開倉量 = 0.1;
input int InpPendingNum = 3;
input double InpGridDensity = 1.0;
input int GridSpace = 0;

int PendingNum;
double GridDensity;

int MyMagicNum = 12090621;
string MyOrderComment = "lyGold";

CTrade trade;
int emaHandle;

double Lots;
int currentGridSpace;
int FontSize = 10;
double BasePrice = 0;

int BuyGroupOrders;
int BuyLimitOrders;
int BuyStopOrders;

//+------------------------------------------------------------------+
int OnInit()
  {
   PendingNum = InpPendingNum;
   GridDensity = InpGridDensity;
   Lots = 開倉量;
   if(Lots < SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN)) Lots = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   
   if(PendingNum < 3) PendingNum = 3;
   if(GridDensity < 1) GridDensity = 1;
   
   int stopLevel = (int)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   if(GridSpace == 0) currentGridSpace = (int)((stopLevel * 2) / GridDensity);
   else currentGridSpace = (int)(GridSpace * 2 / GridDensity);
   
   if(currentGridSpace == 0) currentGridSpace = 100;
   
   trade.SetExpertMagicNumber(MyMagicNum);
   emaHandle = iMA(Symbol(), PERIOD_H1, 120, 0, MODE_SMA, PRICE_CLOSE);
   
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(emaHandle);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   iShowInfo();
   iLimitTakeProfit();
   iComplianceRepair();
   
   if(BuyGroupOrders == 0 && iTradingSignals() == 0)
     {
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      trade.Buy(Lots, Symbol(), ask, 0, 0, MyOrderComment + DoubleToString(ask, _Digits));
     }
  }

//+------------------------------------------------------------------+
void iShowInfo()
  {
   BuyGroupOrders = 0;
   BuyLimitOrders = 0;
   BuyStopOrders = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MyMagicNum && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         BuyGroupOrders++;
        }
     }
     
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(t > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == MyMagicNum)
        {
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT) BuyLimitOrders++;
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) BuyStopOrders++;
        }
     }
  }

//+------------------------------------------------------------------+
int iTradingSignals()
  {
   double myEMA[1];
   if(CopyBuffer(emaHandle, 0, 1, 1, myEMA) > 0)
     {
      if(SymbolInfoDouble(Symbol(), SYMBOL_ASK) > myEMA[0]) return 0;
      if(SymbolInfoDouble(Symbol(), SYMBOL_BID) < myEMA[0]) return 1;
     }
   return 9;
  }

//+------------------------------------------------------------------+
void iLimitTakeProfit()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MyMagicNum && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         
         if(bid > (openPrice + currentGridSpace * _Point))
           {
            trade.PositionClose(ticket);
            continue;
           }
           
         double myTPPrice = 0;
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, MyOrderComment) == 0)
           {
            string priceStr = StringSubstr(comment, StringLen(MyOrderComment));
            double parsePrice = StringToDouble(priceStr);
            if(parsePrice > 0) myTPPrice = parsePrice + currentGridSpace * _Point;
            else myTPPrice = openPrice + currentGridSpace * _Point;
           }
         else
           {
            myTPPrice = openPrice + currentGridSpace * _Point;
           }
           
         double currentTP = PositionGetDouble(POSITION_TP);
         if(NormalizeDouble(currentTP, _Digits) != NormalizeDouble(myTPPrice, _Digits) && bid < myTPPrice)
           {
            trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), myTPPrice);
           }
        }
     }
  }

//+------------------------------------------------------------------+
ulong GetPendingOrderTicketByPrice(ENUM_ORDER_TYPE type, bool highest)
  {
   ulong targetTicket = 0;
   double targetPrice = highest ? 0.0 : 9999999.0;
   bool found = false;
   
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(t > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == MyMagicNum && OrderGetInteger(ORDER_TYPE) == type)
        {
         double price = OrderGetDouble(ORDER_PRICE_OPEN);
         if(!found || (highest && price > targetPrice) || (!highest && price < targetPrice))
           {
            targetPrice = price;
            targetTicket = t;
            found = true;
           }
        }
     }
   return targetTicket;
  }

//+------------------------------------------------------------------+
ulong GetPositionTicketByPrice(ENUM_POSITION_TYPE type, bool highest)
  {
   ulong targetTicket = 0;
   double targetPrice = highest ? 0.0 : 9999999.0;
   bool found = false;
   
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MyMagicNum && PositionGetInteger(POSITION_TYPE) == type)
        {
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(!found || (highest && price > targetPrice) || (!highest && price < targetPrice))
           {
            targetPrice = price;
            targetTicket = t;
            found = true;
           }
        }
     }
   return targetTicket;
  }

//+------------------------------------------------------------------+
void iComplianceRepair()
  {
   if(BuyGroupOrders == 0) return;
   
   ulong lastBuyTicket = 0;
   datetime lastTime = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == MyMagicNum && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         datetime time = (datetime)PositionGetInteger(POSITION_TIME);
         if(time > lastTime)
           {
            lastTime = time;
            lastBuyTicket = t;
           }
        }
     }
     
   if(lastBuyTicket > 0 && PositionSelectByTicket(lastBuyTicket))
     {
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, MyOrderComment) == 0)
        {
         string priceStr = StringSubstr(comment, StringLen(MyOrderComment));
         BasePrice = StringToDouble(priceStr);
        }
      else BasePrice = PositionGetDouble(POSITION_PRICE_OPEN);
     }
     
   if(BasePrice == 0) return;
   
   int myNetNum = PendingNum * 3;
   double myGridArray[];
   ArrayResize(myGridArray, myNetNum);
   ArrayInitialize(myGridArray, 0.0);
   myGridArray[0] = BasePrice + currentGridSpace * _Point * PendingNum;
   
   for(int i = 1; i < myNetNum; i++)
     {
      myGridArray[i] = myGridArray[i - 1] - currentGridSpace * _Point;
     }
     
   ulong lowestLimitTicket = GetPendingOrderTicketByPrice(ORDER_TYPE_BUY_LIMIT, false);
   double lowestLimitPrice = 0;
   if(lowestLimitTicket > 0 && OrderSelect(lowestLimitTicket)) lowestLimitPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   
   if(BuyLimitOrders < (PendingNum * 2) && lowestLimitTicket > 0 && (BasePrice - lowestLimitPrice) / (currentGridSpace * _Point) > (PendingNum * 2))
     {
      double myTempLimitPrice1 = lowestLimitPrice - currentGridSpace * _Point;
      trade.BuyLimit(Lots, myTempLimitPrice1, Symbol(), 0, 0, 0, 0, MyOrderComment + DoubleToString(myTempLimitPrice1, _Digits));
     }
     
   if(BuyLimitOrders > (PendingNum * 2) && lowestLimitTicket > 0 && (BasePrice - lowestLimitPrice) / (currentGridSpace * _Point) > (PendingNum * 2))
     {
      trade.OrderDelete(lowestLimitTicket);
     }
     
   for(int cnt = 0; cnt < myNetNum; cnt++)
     {
      if(myGridArray[cnt] == 0) break;
      string mytempstring = "";
      
      for(int i = 0; i < OrdersTotal(); i++)
        {
         ulong t = OrderGetTicket(i);
         if(t > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == MyMagicNum)
           {
            string comment = OrderGetString(ORDER_COMMENT);
            if(StringFind(comment, DoubleToString(myGridArray[cnt], _Digits)) >= 0)
              {
               mytempstring = "found";
              }
           }
        }
        
      double stopLevel = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(mytempstring == "" && myGridArray[cnt] < (SymbolInfoDouble(Symbol(), SYMBOL_BID) - stopLevel) && (cnt == 0 || myGridArray[cnt - 1] != 0))
        {
         trade.BuyLimit(Lots, myGridArray[cnt], Symbol(), 0, 0, 0, 0, MyOrderComment + DoubleToString(myGridArray[cnt], _Digits));
        }
     }
     
   if(BuyStopOrders < PendingNum)
     {
      double myTempBuyStopPrice = 0;
      ulong highestStopTicket = GetPendingOrderTicketByPrice(ORDER_TYPE_BUY_STOP, true);
      
      if(highestStopTicket > 0 && OrderSelect(highestStopTicket))
        {
         string comment = OrderGetString(ORDER_COMMENT);
         if(StringFind(comment, MyOrderComment) == 0)
           {
            string priceStr = StringSubstr(comment, StringLen(MyOrderComment));
            double parsePrice = StringToDouble(priceStr);
            if(parsePrice > 0) myTempBuyStopPrice = parsePrice + currentGridSpace * _Point;
            else myTempBuyStopPrice = OrderGetDouble(ORDER_PRICE_OPEN) + currentGridSpace * _Point;
           }
         else
           {
            myTempBuyStopPrice = OrderGetDouble(ORDER_PRICE_OPEN) + currentGridSpace * _Point;
           }
        }
      else
        {
         ulong highestBuyTicket = GetPositionTicketByPrice(POSITION_TYPE_BUY, true);
         if(highestBuyTicket > 0 && PositionSelectByTicket(highestBuyTicket))
           {
            myTempBuyStopPrice = BasePrice + currentGridSpace * _Point;
           }
        }
        
      if(myTempBuyStopPrice > 0)
        {
         trade.BuyStop(Lots, myTempBuyStopPrice, Symbol(), 0, 0, 0, 0, MyOrderComment + DoubleToString(myTempBuyStopPrice, _Digits));
        }
     }
  }
//+------------------------------------------------------------------+
