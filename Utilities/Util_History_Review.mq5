//+------------------------------------------------------------------+
//|                                         Util_History_Review.mq5 |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

input color TextColor = clrRed;
int cnt;
string TextBarString, DotBarString, HLineBarString, VLineBarString; 

int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Comment("");
   ObjectsDeleteAll(0, -1, OBJ_LABEL);
   ObjectsDeleteAll(0, -1, OBJ_TREND);
   ObjectsDeleteAll(0, -1, OBJ_TEXT);
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
   iMain();
   return(rates_total);
  }

void iMain()
  {
   //定義統計變數
   int BuyHistoryOrders=0, SellHistoryOrders=0, ProfitHistoryOrders=0, HistoryOrderTotal=0;
   int WinHistory=0, LossHistory=0; 
   double TotalHistoryLots=0;
   double TotalHistoryProfit=0, TotalHistoryLoss=0;
   color myLineColor = clrBlue;
   
   MqlDateTime dt;
   TimeCurrent(dt);
   iDisplayInfo("Times", "動態報價時間:" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " 星期" + IntegerToString(dt.day_of_week), 0, 4, 15, 9, "Verdana", TextColor);
   
   //遍歷歷史訂單，計算相關資訊 (MT5 使用 Deals)
   HistorySelect(0, TimeCurrent());
   int dealsTotal = HistoryDealsTotal();
   
   for (cnt = 0; cnt < dealsTotal; cnt++)
     {
      ulong dealTicket = HistoryDealGetTicket(cnt);
      if (dealTicket > 0)
        {
         long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT) // 平倉成交單
           {
            if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) == Symbol())
              {
               long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
               double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               double vol = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
               datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
               double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
               long posID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
               
               // 找開倉的 Deal 以獲取開倉時間與價格
               datetime openTime = 0;
               double openPrice = 0;
               for (int j = 0; j < dealsTotal; j++)
                 {
                  ulong inTicket = HistoryDealGetTicket(j);
                  if (HistoryDealGetInteger(inTicket, DEAL_POSITION_ID) == posID && 
                      HistoryDealGetInteger(inTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                    {
                     openTime = (datetime)HistoryDealGetInteger(inTicket, DEAL_TIME);
                     openPrice = HistoryDealGetDouble(inTicket, DEAL_PRICE);
                     break;
                    }
                 }
                 
               bool wasBuy = (dealType == DEAL_TYPE_SELL); // 平倉為Sell代表原本持多單
               bool wasSell = (dealType == DEAL_TYPE_BUY); // 平倉為Buy代表原本持空單
               
               if (wasBuy) BuyHistoryOrders++;
               if (wasSell) SellHistoryOrders++;
               TotalHistoryLots += vol;
               
               if (profit > 0)
                 {
                  WinHistory++;
                  TotalHistoryProfit += profit;
                  myLineColor = clrBlue;
                 }
               else if (profit < 0)
                 {
                  LossHistory++;
                  TotalHistoryLoss += profit;
                  myLineColor = clrRed;
                 }
                 
               if (openTime > 0)
                 {
                  string labelPrefix = TimeToString(openTime);
                  if (wasBuy)
                    {
                     iTwoPointsLine(labelPrefix, openTime, openPrice, closeTime, closePrice, STYLE_DOT, myLineColor);
                     iDrawSign("Text", openTime, openPrice, myLineColor, 0, IntegerToString(dealTicket) + " buy", 8);
                    }
                  else if (wasSell)
                    {
                     iTwoPointsLine(labelPrefix, openTime, openPrice, closeTime, closePrice, STYLE_DASHDOT, myLineColor);
                     iDrawSign("Text", openTime, openPrice, myLineColor, 0, IntegerToString(dealTicket) + " sell", 8);
                    }
                 }
              }
           }
        }
     }
     
   HistoryOrderTotal = BuyHistoryOrders + SellHistoryOrders;
   iDisplayInfo("HistoryOrderTotal", "歷史交易單總計:" + IntegerToString(HistoryOrderTotal) + "  (其中買入單:" + IntegerToString(BuyHistoryOrders) + "  賣出單:" + IntegerToString(SellHistoryOrders) + ")", 0, 4, 35, 9, "", TextColor);
   
   double myWinRate = 0;
   if (HistoryOrderTotal > 0) myWinRate = (WinHistory * 1.00) / (HistoryOrderTotal * 1.00) * 100; 
   iDisplayInfo("HistoryWinLoss", "歷史盈利單總計:" + IntegerToString(WinHistory) + "  歷史虧損單:" + IntegerToString(LossHistory) + "  勝率:" + DoubleToString(myWinRate, 2) + "%", 0, 4, 50, 9, "", TextColor);
   iDisplayInfo("HistoryLots", "歷史總下單量:" + DoubleToString(TotalHistoryLots, 2) + "手" + "  總盈利:" + DoubleToString(TotalHistoryProfit, 2) + "  總虧損:" + DoubleToString(TotalHistoryLoss, 2), 0, 4, 65, 9, "", TextColor);
   
   double myOdds = 0;
   if (WinHistory > 0 && LossHistory > 0 && TotalHistoryLoss != 0)
     {
      myOdds = (TotalHistoryProfit / WinHistory) / (-TotalHistoryLoss / LossHistory); 
     }
     
   double myKelly = 0;
   if (myOdds > 0)
     {
      myKelly = ((myOdds + 1) * (myWinRate / 100) - 1) / myOdds;
      if (myKelly < 0) myKelly = -myKelly;
     }
     
   double marginRequired = 1000;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), 1.0, SymbolInfoDouble(Symbol(), SYMBOL_ASK), marginRequired)) marginRequired = 1000;
   double myMaxLots = 0;
   if(marginRequired > 0) myMaxLots = AccountInfoDouble(ACCOUNT_BALANCE) * myKelly / marginRequired;
   
   double avgProfit = (WinHistory > 0) ? (TotalHistoryProfit / WinHistory) : 0;
   double avgLoss = (LossHistory > 0) ? (TotalHistoryLoss / LossHistory) : 0;
   
   iDisplayInfo("AverageRate", "平均盈利:" + DoubleToString(avgProfit, 2) + "  平均虧損:" + DoubleToString(avgLoss, 2), 0, 4, 80, 9, "", TextColor);
   iDisplayInfo("Kelly", "賠率:" + DoubleToString(myOdds, 2) + "  凱利指標:" + DoubleToString(myKelly * 100, 2) + "%" +
                "  持倉限制:" + DoubleToString(myMaxLots, 2) + "手", 0, 4, 95, 9, "", TextColor);
                
   //持倉警告
   double myLots = 0;
   for (cnt = 0; cnt < PositionsTotal(); cnt++)
     {
      ulong posTicket = PositionGetTicket(cnt);
      if (posTicket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         myLots += PositionGetDouble(POSITION_VOLUME);
         double profit = PositionGetDouble(POSITION_PROFIT);
         long posType = PositionGetInteger(POSITION_TYPE);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         
         if (profit > 0) myLineColor = clrBlue;
         if (profit < 0) myLineColor = clrRed;
         
         string timeStr = TimeToString(openTime);
         ObjectDelete(0, timeStr);
         ObjectDelete(0, "Text" + timeStr);
         
         double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         int style = (posType == POSITION_TYPE_BUY) ? STYLE_DOT : STYLE_DASHDOT;
         string textType = (posType == POSITION_TYPE_BUY) ? " buy" : " sell";
         
         iTwoPointsLine(timeStr, openTime, openPrice, TimeCurrent(), currentPrice, style, myLineColor);
         iDrawSign("Text", openTime, openPrice, myLineColor, 0, IntegerToString(posTicket) + textType, 8);
        }
     }
     
   if (myLots > myMaxLots && myMaxLots > 0)
     {
      iDisplayInfo("Waring", "持倉量已超過警戒線，請慎重下單!", 0, 4, 110, 12, "黑體", clrOlive);
     }
   else 
     {
      iDisplayInfo("Waring", "", 0, 4, 110, 12, "", clrOlive);
     }
  }

void iDisplayInfo(string LableName, string LableDoc, int CornerPos, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   if (CornerPos == -1) return;
   ObjectCreate(0, LableName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   if(DocStyle != "") ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
   ObjectSetInteger(0, LableName, OBJPROP_CORNER, CornerPos);
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
  }

void iTwoPointsLine(string myLineName, datetime myFirstTime, double myFirstPrice, datetime mySecondTime, double mySecondPrice, int myLineStyle, color myLineColor)
  {
   ObjectCreate(0, myLineName, OBJ_TREND, 0, myFirstTime, myFirstPrice, mySecondTime, mySecondPrice);
   ObjectSetInteger(0, myLineName, OBJPROP_STYLE, myLineStyle);
   ObjectSetInteger(0, myLineName, OBJPROP_COLOR, myLineColor);
   ObjectSetInteger(0, myLineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, myLineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, myLineName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, myLineName, OBJPROP_RAY_LEFT, false);
  }

void iDrawSign(string myType, datetime barTime, double myPrice, color myColor, int mySymbol, string myString, int myDocSize)
  {
   if (myType == "Text")
     {
      TextBarString = "Text" + TimeToString(barTime);
      ObjectCreate(0, TextBarString, OBJ_TEXT, 0, barTime, myPrice);
      ObjectSetInteger(0, TextBarString, OBJPROP_COLOR, myColor);
      ObjectSetInteger(0, TextBarString, OBJPROP_FONTSIZE, myDocSize);
      ObjectSetString(0, TextBarString, OBJPROP_TEXT, myString);
      ObjectSetInteger(0, TextBarString, OBJPROP_BACK, true);
     }
   if (myType == "Dot")
     {
      DotBarString = myType + TimeToString(barTime);
      ObjectCreate(0, DotBarString, OBJ_ARROW, 0, barTime, myPrice);
      ObjectSetInteger(0, DotBarString, OBJPROP_COLOR, myColor);
      ObjectSetInteger(0, DotBarString, OBJPROP_ARROWCODE, mySymbol);
      ObjectSetInteger(0, DotBarString, OBJPROP_BACK, false);
     }
   if (myType == "HLine")
     {
      HLineBarString = myType + TimeToString(barTime);
      ObjectCreate(0, HLineBarString, OBJ_HLINE, 0, barTime, myPrice);
      ObjectSetInteger(0, HLineBarString, OBJPROP_COLOR, myColor);
      ObjectSetInteger(0, HLineBarString, OBJPROP_BACK, false);
     }
   if (myType == "VLine")
     {
      VLineBarString = myType + TimeToString(barTime);
      ObjectCreate(0, VLineBarString, OBJ_VLINE, 0, barTime, myPrice);
      ObjectSetInteger(0, VLineBarString, OBJPROP_COLOR, myColor);
      ObjectSetInteger(0, VLineBarString, OBJPROP_BACK, false);
     }
  }
