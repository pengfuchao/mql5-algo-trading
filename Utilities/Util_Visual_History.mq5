//+------------------------------------------------------------------+
//|                                          Util_Visual_History.mq5 |
//+------------------------------------------------------------------+
//指標在主圖顯示
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "買入訂單開盤價"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrGreen
#property indicator_width1  1

#property indicator_label2  "賣出訂單開盤價"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "平倉價"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDarkOrange
#property indicator_width3  1

//定義買入訂單開盤箭頭、賣出訂單開盤箭頭平倉符號
double OpenBuyArrow[];
double OpenSellArrow[];
double CloseArrow[];

int OnInit()
  {
   PlotIndexSetInteger(0, PLOT_ARROW, 221);
   PlotIndexSetInteger(1, PLOT_ARROW, 222);
   PlotIndexSetInteger(2, PLOT_ARROW, 251);

   SetIndexBuffer(0, OpenBuyArrow, INDICATOR_DATA);
   SetIndexBuffer(1, OpenSellArrow, INDICATOR_DATA);
   SetIndexBuffer(2, CloseArrow, INDICATOR_DATA);
   
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, -1, OBJ_LABEL);
   ObjectsDeleteAll(0, -1, OBJ_TREND);
  }

void OnTimer()
  {
   // 每秒強制觸發畫面更新
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
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(OpenBuyArrow, true);
   ArraySetAsSeries(OpenSellArrow, true);
   ArraySetAsSeries(CloseArrow, true);
   
   if(prev_calculated == 0)
     {
      ArrayInitialize(OpenBuyArrow, EMPTY_VALUE);
      ArrayInitialize(OpenSellArrow, EMPTY_VALUE);
      ArrayInitialize(CloseArrow, EMPTY_VALUE);
     }
     
   ObjectsDeleteAll(0, -1, OBJ_TREND);
   
   int BuyOrders = 0, SellOrders = 0, ProfitOrders = 0;
   double TotalTrades = 0;
   double TotalProfit = 0, TotalLoss = 0;
   
   SetLable("標題列", "作品：", 200, 1, 8, "黑體", clrRed);
   MqlDateTime dt;
   TimeCurrent(dt);
   SetLable("時間欄", "動態報價時間: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " 星期" + IntegerToString(dt.day_of_week), 4, 15, 9, "Verdana", clrRed);
   
   // 歷史訂單分析
   HistorySelect(0, TimeCurrent());
   int dealsTotal = HistoryDealsTotal();
   int HistoryOrderTotal = 0;
   
   for (int i = 0; i < dealsTotal; i++)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if (dealTicket > 0)
        {
         long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
           {
            if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) == Symbol())
              {
               HistoryOrderTotal++;
               long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
               double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               double vol = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
               datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
               double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
               long posID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
               
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
                 
               bool wasBuy = (dealType == DEAL_TYPE_SELL); 
               bool wasSell = (dealType == DEAL_TYPE_BUY); 
               
               int openBar = iBarShift(Symbol(), PERIOD_CURRENT, openTime);
               int closeBar = iBarShift(Symbol(), PERIOD_CURRENT, closeTime);
               
               if (wasBuy)
                 {
                  if(openBar >= 0 && openBar < rates_total) OpenBuyArrow[openBar] = openPrice;
                  BuyOrders++;
                  if (profit > 0) { TotalProfit += profit; ProfitOrders++; }
                  if (profit < 0) TotalLoss += profit;
                 }
               if (wasSell)
                 {
                  if(openBar >= 0 && openBar < rates_total) OpenSellArrow[openBar] = openPrice;
                  SellOrders++;
                  if (profit > 0) { TotalProfit += profit; ProfitOrders++; }
                  if (profit < 0) TotalLoss += profit;
                 }
                 
               TotalTrades += vol;
               if(closeBar >= 0 && closeBar < rates_total) CloseArrow[closeBar] = closePrice;
               
               SetObj(dealTicket, wasBuy ? 0 : 1, openTime, openPrice, closeTime, closePrice);
              }
           }
        }
     }
     
   // 當前持倉訂單
   for (int j = 0; j < PositionsTotal(); j++)
     {
      ulong posTicket = PositionGetTicket(j);
      if (posTicket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         long posType = PositionGetInteger(POSITION_TYPE);
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         
         string NowObjectName = "訂單號：" + IntegerToString(posTicket);
         ObjectDelete(0, NowObjectName);
         
         int openBar = iBarShift(Symbol(), PERIOD_CURRENT, openTime);
         if(openBar >= 0 && openBar < rates_total)
           {
            if (posType == POSITION_TYPE_BUY) OpenBuyArrow[openBar] = openPrice;
            if (posType == POSITION_TYPE_SELL) OpenSellArrow[openBar] = openPrice;
           }
           
         SetObj(posTicket, (int)posType, openTime, openPrice, TimeCurrent(), currentPrice);
        }
     }
     
   // 顯示統計資訊
   SetLable("交易單統計", "歷史交易單總計:" + IntegerToString(HistoryOrderTotal) + "  (買入訂單:" + IntegerToString(BuyOrders) + " 賣出訂單:" + IntegerToString(SellOrders) + ")", 4, 35, 9, "Verdana", clrGray);
   
   double winRate = 0;
   if(HistoryOrderTotal > 0) winRate = (ProfitOrders * 1.00) / (HistoryOrderTotal * 1.00) * 100;
   SetLable("勝率", "盈利訂單百分比:" + DoubleToString(winRate, 2) + "%", 4, 50, 9, "Verdana", clrGray);
   
   SetLable("盈虧統計", "淨盈利:" + DoubleToString(TotalProfit + TotalLoss, 2) + "  (總獲利:" + DoubleToString(TotalProfit, 2) + "  總虧損:" + DoubleToString(TotalLoss, 2) + ")", 4, 65, 9, "Verdana", clrGray);
   
   SetLable("帳戶餘額", "帳戶餘額:" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " 帳戶淨值:" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), 4, 80, 9, "Verdana", clrGray);
   SetLable("下單量", "總下單量(手):" + DoubleToString(TotalTrades, 2), 4, 95, 9, "Verdana", clrGray);
   
   return(rates_total);
  }

void SetObj(ulong myOrderTicket, int myOrderType, datetime myOpenTime, double myOpenPrice, datetime myCloseTime, double myClosePrice)
  {
   string myObjectName = "訂單號：" + IntegerToString(myOrderTicket);
   ObjectCreate(0, myObjectName, OBJ_TREND, 0, myOpenTime, myOpenPrice, myCloseTime, myClosePrice);
   if (myOrderType == 0) ObjectSetInteger(0, myObjectName, OBJPROP_COLOR, clrGreen);
   if (myOrderType == 1) ObjectSetInteger(0, myObjectName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, myObjectName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, myObjectName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, myObjectName, OBJPROP_BACK, false);
   ObjectSetInteger(0, myObjectName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, myObjectName, OBJPROP_RAY_LEFT, false);
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
