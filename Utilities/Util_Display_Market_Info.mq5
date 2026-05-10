//+------------------------------------------------------------------+
//|                                     Util_Display_Market_Info.mq5 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   double marginBuy = 0.0;
   double marginSell = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), 1.0, SymbolInfoDouble(Symbol(), SYMBOL_ASK), marginBuy)) marginBuy = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_SELL, Symbol(), 1.0, SymbolInfoDouble(Symbol(), SYMBOL_BID), marginSell)) marginSell = 0.0;
   
   Comment("===================="+"\n"+
           "交易商："+TerminalInfoString(TERMINAL_COMPANY)+
           "  交易平臺："+TerminalInfoString(TERMINAL_NAME)+
           "  伺服器的名稱："+AccountInfoString(ACCOUNT_SERVER)+"\n"+
           "開戶公司："+ AccountInfoString(ACCOUNT_COMPANY)+
           "  帳號："+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+
           "  帳戶名稱："+AccountInfoString(ACCOUNT_NAME)+
           "  交易貨幣："+AccountInfoString(ACCOUNT_CURRENCY)+
           "  杠杆：1:"+IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE))+"\n"+
           "===================="+"\n"+
           "當前品種："+Symbol()+
           "  當前點差："+IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD))+
           "  停止水準點："+IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL))+"\n"+
           "報價小數位數："+IntegerToString(_Digits)+
           "  最小報價單位："+DoubleToString(_Point, _Digits)+"\n"+
           "1標準手價值："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE), 0)+
           "  1個點價值："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE), 4)+
           "  1個點報價："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE), _Digits)+"\n"+
           "最小開倉手數："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN), 2)+
           "  最大允許標準手數："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX), 0)+
           "  開倉量最小遞增量："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP), 2)+"\n"+
           "1標準手的護盤保證金："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_MARGIN_HEDGED), 2)+
           "  1標準手的初始保證金："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_MARGIN_INITIAL), 2)+"\n"+
           "凍結定單水準點："+IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_TRADE_FREEZE_LEVEL))+
           "  帳戶信用點數："+DoubleToString(AccountInfoDouble(ACCOUNT_CREDIT), 2)+"\n"+
           "===================="+"\n"+
           "帳戶餘額："+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2)+
           "  帳戶淨值："+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2)+
           "  已用保證金："+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2)+
           "  帳戶利潤："+DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2)+"\n"+
           "當前可用保證金："+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2)+
           "  停止水準值："+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), 2)+"\n"+
           "當前價格買入1手保證金："+DoubleToString(marginBuy, 2)+
           "  當前價格賣出1手保證金："+DoubleToString(marginSell, 2)+"\n"+
           "買入持倉單隔夜利息："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_SWAP_LONG), 2)+
           "  賣出持倉單隔夜利息："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_SWAP_SHORT), 2)+"\n"+
           "===================="
           );
  }
