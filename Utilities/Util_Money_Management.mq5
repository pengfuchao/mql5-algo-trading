//+------------------------------------------------------------------+
//|                                        Util_Money_Management.mq5 |
//+------------------------------------------------------------------+
/*
函    數:開倉量整形
輸入參數:myLots:開倉量
輸出參數:按照平臺規則計算開倉量
算    法:調整不規範的開倉量資料，按照四捨五入原則及平臺開倉量格式規範資料
*/
double iLotsFormat(double myLots)
   {
      double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
      double stepLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
      if(stepLot == 0) stepLot = minLot; // 防呆處理
      
      myLots = MathRound(myLots / stepLot) * stepLot; //開倉量整形
      if (myLots < minLot)
         {
            myLots = minLot;
         }
      return(myLots);
   }

/*
函    數：金額轉換手數
輸入參數：mySymbol:商品名稱
          myFunds:資金基數
輸出參數：轉換後的可開倉手數
*/
double iFundsToHands(string mySymbol, double myFunds)
   {
      // MT5 中獲取所需保證金較為複雜，這裡簡單使用初始保證金
      double marginRequired = 0;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, mySymbol, 1.0, SymbolInfoDouble(mySymbol, SYMBOL_ASK), marginRequired))
         {
            marginRequired = 1000; // 預設值，若無法獲取
         }
         
      double myLots = myFunds / marginRequired; //換算可開倉手數
      myLots = iLotsFormat(myLots); //手數整形
      return(myLots);
   }

/*
函    數：訂單利潤轉換點數
輸入參數：myTicket:訂單號 (Position Ticket)
輸出參數：利潤對應的點數
*/
int iOrderProfitToPoint(ulong myTicket)
   {
      int myPoint=0;
      if (PositionSelectByTicket(myTicket))
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            double swap = PositionGetDouble(POSITION_SWAP);
            string sym = PositionGetString(POSITION_SYMBOL);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
            
            if(tickValue > 0 && volume > 0)
               {
                  myPoint = (int)NormalizeDouble(((profit - swap) / tickValue) / volume, 0);
               }
         }
      return(myPoint);
   }

/*
函    數：按資金比例計算開倉量
輸入參數：myFunds:資金基數，myCapitalRisk:資金比例 (例如20表示20%)
輸出參數：在指定的風險比例下，計算最大下單量
*/
double iLotsOptimized(double myFunds, double myCapitalRisk)
   {
      double myMargin = myFunds * myCapitalRisk / 100.0; //計算可用保證金額度
      double myLots = iLotsFormat(iFundsToHands(Symbol(), myMargin)); //換算可開倉手數
      return(myLots);
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
  }
