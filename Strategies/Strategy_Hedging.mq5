//+------------------------------------------------------------------+
//|                                           Strategy_Hedging.mq5   |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input string str1 = "====系統預設參數====";
input double 預設開倉量 = 0.01;
input int 止盈 = 1500;
input int 止損 = 3000;
input int 掛單間距 = 1500;

input string 訂單注釋 = ""; 
input ulong 訂單特徵碼 = 9999;

CTrade trade;
int maHandle;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(訂單特徵碼);
   
   maHandle = iMA(Symbol(), PERIOD_CURRENT, 36, 0, MODE_SMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE)
     {
      Print("無法載入 MA 指標！");
      return(INIT_FAILED);
     }
     
   iDisplayInfo("TradeInfo", "^_^快樂交易^_^ ", 1, 5, 50, 9, "", clrOlive);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
   ObjectsDeleteAll(0, -1, OBJ_LABEL);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   iShowInfo();
   
   int buyPositions = 0, sellPositions = 0;
   int buyStops = 0, sellStops = 0;
   ulong lastBuyTicket = 0, lastSellTicket = 0;
   datetime lastBuyTime = 0, lastSellTime = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == 訂單特徵碼)
        {
         long type = PositionGetInteger(POSITION_TYPE);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         
         if(type == POSITION_TYPE_BUY)
           {
            buyPositions++;
            if(openTime > lastBuyTime) { lastBuyTime = openTime; lastBuyTicket = ticket; }
           }
         else if(type == POSITION_TYPE_SELL)
           {
            sellPositions++;
            if(openTime > lastSellTime) { lastSellTime = openTime; lastSellTicket = ticket; }
           }
        }
     }
     
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == 訂單特徵碼)
        {
         long type = OrderGetInteger(ORDER_TYPE);
         if(type == ORDER_TYPE_BUY_STOP) buyStops++;
         if(type == ORDER_TYPE_SELL_STOP) sellStops++;
        }
     }
     
   // 3. 如果持倉單出場，刪除掛單，回到第1步
   if(buyPositions == 0 && sellPositions == 0 && (buyStops + sellStops) > 0)
     {
      iDisplayInfo("TradeInfo", "結束交易，刪除掛單", 1, 5, 50, 9, "", clrOlive);
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == 訂單特徵碼)
           {
            trade.OrderDelete(ticket);
           }
        }
      return;
     }
     
   // 2. 給持倉單設置止盈止損，在掛單間距位置掛一張與最後一張持倉單類型反向，開倉量2倍的stop單
   if(lastBuyTicket > 0)
     {
      if(PositionSelectByTicket(lastBuyTicket))
        {
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double lots = PositionGetDouble(POSITION_VOLUME);
         
         if(sl == 0 || tp == 0)
           {
            iDisplayInfo("TradeInfo", "持倉單設置止盈止損", 1, 5, 50, 9, "", clrOlive);
            trade.PositionModify(lastBuyTicket, NormalizeDouble(openPrice - 止損 * _Point, _Digits), NormalizeDouble(openPrice + 止盈 * _Point, _Digits));
           }
           
         if(lastBuyTime >= lastSellTime && sellStops == 0)
           {
            iDisplayInfo("TradeInfo", "新建SellStop掛單", 1, 5, 50, 9, "", clrOlive);
            trade.SellStop(lots * 2, NormalizeDouble(openPrice - 掛單間距 * _Point, _Digits), Symbol(), 0, 0, ORDER_TIME_GTC, 0, 訂單注釋);
           }
        }
     }
     
   if(lastSellTicket > 0)
     {
      if(PositionSelectByTicket(lastSellTicket))
        {
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double lots = PositionGetDouble(POSITION_VOLUME);
         
         if(sl == 0 || tp == 0)
           {
            iDisplayInfo("TradeInfo", "持倉單設置止盈止損", 1, 5, 50, 9, "", clrOlive);
            trade.PositionModify(lastSellTicket, NormalizeDouble(openPrice + 止損 * _Point, _Digits), NormalizeDouble(openPrice - 止盈 * _Point, _Digits));
           }
           
         if(lastSellTime >= lastBuyTime && buyStops == 0)
           {
            iDisplayInfo("TradeInfo", "新建BuyStop掛單", 1, 5, 50, 9, "", clrOlive);
            trade.BuyStop(lots * 2, NormalizeDouble(openPrice + 掛單間距 * _Point, _Digits), Symbol(), 0, 0, ORDER_TIME_GTC, 0, 訂單注釋);
           }
        }
     }
     
   // 1. 市價建立一張買入或賣出持倉單
   if(buyPositions + sellPositions + buyStops + sellStops == 0)
     {
      double maArray[1];
      if(CopyBuffer(maHandle, 0, 0, 1, maArray) < 1) return;
      double myMA = maArray[0];
      
      if(SymbolInfoDouble(Symbol(), SYMBOL_ASK) > myMA)
        {
         iDisplayInfo("TradeInfo", "新建買入持倉單", 1, 5, 50, 9, "", clrOlive);
         trade.Buy(預設開倉量, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_ASK), 0, 0, 訂單注釋);
        }
      else if(SymbolInfoDouble(Symbol(), SYMBOL_BID) < myMA)
        {
         iDisplayInfo("TradeInfo", "新建賣出持倉單", 1, 5, 50, 9, "", clrOlive);
         trade.Sell(預設開倉量, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, 訂單注釋);
        }
     }
  }

void iShowInfo()
  {
   int BuyGroupOrders = 0, SellGroupOrders = 0;
   int BuyStopOrders = 0, SellStopOrders = 0;
   double BuyGroupLots = 0, SellGroupLots = 0;
   double BuyGroupProfit = 0, SellGroupProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == 訂單特徵碼)
        {
         long type = PositionGetInteger(POSITION_TYPE);
         double lots = PositionGetDouble(POSITION_VOLUME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(type == POSITION_TYPE_BUY) { BuyGroupOrders++; BuyGroupLots += lots; BuyGroupProfit += profit; }
         if(type == POSITION_TYPE_SELL) { SellGroupOrders++; SellGroupLots += lots; SellGroupProfit += profit; }
        }
     }
     
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == 訂單特徵碼)
        {
         long type = OrderGetInteger(ORDER_TYPE);
         if(type == ORDER_TYPE_BUY_STOP) BuyStopOrders++;
         if(type == ORDER_TYPE_SELL_STOP) SellStopOrders++;
        }
     }
     
   iDisplayInfo("Symbol", Symbol(), 1, 25, 30, 14, "Arial Bold", clrDodgerBlue);
   
   iDisplayInfo(Symbol()+"-BuyGroup", "買入組", 1, 70, 70, 12, "Arial", clrRed);
   iDisplayInfo(Symbol()+"-Ask", DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_ASK), _Digits), 1, 70, 90, 12, "Arial", clrRed);
   iDisplayInfo(Symbol()+"BuyOrders", IntegerToString(BuyGroupOrders)+"  0  "+IntegerToString(BuyStopOrders), 1, 80, 110, 10, "Arial", (BuyGroupProfit >= 0) ? clrGreen : clrRed);
   iDisplayInfo(Symbol()+"BuyGroupLots", DoubleToString(BuyGroupLots, 2), 1, 80, 125, 10, "Arial", (BuyGroupProfit >= 0) ? clrGreen : clrRed);
   iDisplayInfo(Symbol()+"BuyGroupProfit", DoubleToString(BuyGroupProfit, 2), 1, 80, 140, 10, "Arial", (BuyGroupProfit >= 0) ? clrGreen : clrRed);
   
   iDisplayInfo(Symbol()+"-SellGroup", "賣出組", 1, 5, 70, 12, "Arial", clrGreen);
   iDisplayInfo(Symbol()+"-Bid", DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits), 1, 5, 90, 12, "Arial", clrGreen);
   iDisplayInfo(Symbol()+"SellOrders", IntegerToString(SellGroupOrders)+"  0  "+IntegerToString(SellStopOrders), 1, 10, 110, 10, "Arial", (SellGroupProfit >= 0) ? clrGreen : clrRed);
   iDisplayInfo(Symbol()+"SellGroupLots", DoubleToString(SellGroupLots, 2), 1, 10, 125, 10, "Arial", (SellGroupProfit >= 0) ? clrGreen : clrRed);
   iDisplayInfo(Symbol()+"SellGroupProfit", DoubleToString(SellGroupProfit, 2), 1, 10, 140, 10, "Arial", (SellGroupProfit >= 0) ? clrGreen : clrRed);
  }

void iDisplayInfo(string LableName, string LableDoc, int Corner, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   if (Corner == -1) return;
   ObjectCreate(0, LableName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
   ObjectSetInteger(0, LableName, OBJPROP_CORNER, Corner);
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   if(DocStyle != "") ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
  }
