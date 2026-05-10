//+------------------------------------------------------------------+
//|                                       Util_Position_Status.mq5 |
//+------------------------------------------------------------------+
//[指標]持倉單狀態
#property indicator_separate_window
#property indicator_plots 0

//程式控制變數
int cnt;

int OnInit()
  {
   // MT5 指標支援 OnTimer，每秒更新一次狀態
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
   iOrdersStatus();
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
   iOrdersStatus();
   return(rates_total);
  }

/*
函    數：顯示訂單狀態
*/
void iOrdersStatus()
  {
   //清除標籤
   int myWindowsHandle = ChartWindowFind(); //獲取當前指標名稱所在窗口序號
   if(myWindowsHandle < 0) myWindowsHandle = 0;
   
   ObjectsDeleteAll(0, myWindowsHandle, OBJ_LABEL);
   
   //顯示資訊
   int myBuyOrder_y = 80;
   int mySellOrder_y = 80;
   double myBuyLots = 0, mySellLots = 0, myBuyProfit = 0, mySellProfit = 0;
   double myBuyLossRate = 0, mySellLossRate = 0, myTotalLossRate = 0;  //虧損率
   int myBuyOrders = 0, mySellOrders = 0;
   
   //顯示持倉單資訊：單號  盈虧
   if (PositionsTotal() > 0)
     {
      for (cnt = 0; cnt < PositionsTotal(); cnt++)
        {
         ulong ticket = PositionGetTicket(cnt);
         if (ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol())
           {
            double vol = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            long type = PositionGetInteger(POSITION_TYPE);
            
            if (type == POSITION_TYPE_BUY)
              {
               iDisplayInfo(IntegerToString(ticket), IntegerToString(ticket) + "  " + DoubleToString(vol, 2) + "  " + DoubleToString(profit, 2), 1, 20, myBuyOrder_y, 10, "Arial", iObjectColor(profit));
               myBuyOrder_y += 15;
               myBuyLots += vol;
               myBuyProfit += profit;
               myBuyOrders += 1;
              }
            if (type == POSITION_TYPE_SELL)
              {
               iDisplayInfo(IntegerToString(ticket), IntegerToString(ticket) + "  " + DoubleToString(vol, 2) + "  " + DoubleToString(profit, 2), 1, 190, mySellOrder_y, 10, "Arial", iObjectColor(profit));
               mySellOrder_y += 15;
               mySellLots += vol;
               mySellProfit += profit;
               mySellOrders += 1;
              }
           }
        }
        
      double myTotalLots = myBuyLots + mySellLots;
      double myTotalProfit = myBuyProfit + mySellProfit;
      int myTotalOrders = myBuyOrders + mySellOrders;
      
      double marginRequired = 1000;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), 1.0, SymbolInfoDouble(Symbol(), SYMBOL_ASK), marginRequired)) marginRequired = 1000;
      
      if (myBuyLots != 0 && marginRequired > 0) myBuyLossRate = 100 * (myBuyProfit / marginRequired) / myBuyLots;
      if (mySellLots != 0 && marginRequired > 0) mySellLossRate = 100 * (mySellProfit / marginRequired) / mySellLots;
      if (myTotalLots != 0 && marginRequired > 0) myTotalLossRate = 100 * (myTotalProfit / marginRequired) / myTotalLots;
      
      iDisplayInfo("INDSymbol", Symbol() + "  " + IntegerToString(myTotalOrders) + "  " + DoubleToString(myTotalLots, 2) + "  " + DoubleToString(myTotalProfit, 2) + "  " + DoubleToString(myTotalLossRate, 2) + "%", 1, 30, 20, 14, "Arial Bold", clrDodgerBlue);
      iDisplayInfo("INDAsk", DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_ASK), _Digits), 1, 40, 40, 14, "Arial Bold", clrRed);
      iDisplayInfo("INDBid", DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits), 1, 220, 40, 14, "Arial Bold", clrGreen);
      
      //按買賣單顯示持倉量、盈虧
      iDisplayInfo(Symbol() + "BUY", IntegerToString(myBuyOrders) + "  " + DoubleToString(myBuyLots, 2) + "  " + DoubleToString(myBuyProfit, 2) + "  " + DoubleToString(myBuyLossRate, 2) + "%", 1, 20, 60, 10, "Arial", iObjectColor(myBuyProfit));
      iDisplayInfo(Symbol() + "SELL", IntegerToString(mySellOrders) + "  " + DoubleToString(mySellLots, 2) + "  " + DoubleToString(mySellProfit, 2) + "  " + DoubleToString(mySellLossRate, 2) + "%", 1, 190, 60, 10, "Arial", iObjectColor(mySellProfit));
     }
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

color iObjectColor(double myInput)
  {
   color myColor = clrDarkGray;
   if (myInput > 0)
      myColor = clrGreen; //正數顏色為綠色
   if (myInput < 0)
      myColor = clrRed;   //負數顏色為紅色
   return(myColor);
  }
