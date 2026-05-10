//+------------------------------------------------------------------+
//|                            Strategy_Indicator_Resonance_Short.mq5|
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

input string str1 = "====系統預設參數====";
input double 開倉量 = 0.1;
input int 止損點 = 200;
input int 加倉時間間隔 = 300;
input int 第二單開倉時間間隔 = 300;
input int 虧損單最大數量 = 4;
input int 最大虧損單虧損點數 = 50;
input int 最小盈利單盈利點數 = 30;
input int 加倉第一次盈利點 = 10;
input int 震盪單止盈點 = 55;
input bool 不開倉限制 = true;
input bool 止損加倉間隔時間先後 = true;
input bool 固定止損 = false;
input bool 清倉開關 = false;
input string 訂單注釋 = "3MSELL";

input string str2 = "====技術指標參數====";
input int 圖表週期1 = 1;
input int 圖表週期2 = 5;
input int 圖表週期3 = 30;
input int 均線平均週期 = 5;
input int 均線平均方法 = 2;
input int 均線使用價格 = 0;
input int 布林平均週期 = 10;
input int 布林偏差值 = 2;
input int 布林使用價格 = 0;

int SellGroupOrders;
ulong SellGroupFirstTicket, SellGroupLastTicket;
double SellGroupLots, SellGroupProfit;
int Magic = 0;
int LastSignal = 2;
int LastSignal2 = 1;
int LastSignal3 = 1;
datetime FirstTakeProfitTime = 0;
ulong SecondTicket = 0;
ulong ShockTicket = 0;
int DecreaseCnt = 0;
bool CloseAll = false;
bool GetFirstTPTime = true;

int iSignalHandle;
int bandsHandle;
CTrade trade;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(0);
   
   iSignalHandle = iCustom(Symbol(), PERIOD_CURRENT, "3MSingal", 圖表週期1, 圖表週期2, 圖表週期3, 均線平均週期, 均線平均方法, 均線使用價格, 布林平均週期, 布林偏差值, 布林使用價格, 0, 0);
   bandsHandle = iBands(Symbol(), PERIOD_M5, 布林平均週期, 0, 布林偏差值, PRICE_CLOSE);
   
   if(iSignalHandle == INVALID_HANDLE)
     {
      Print("無法載入 3MSingal 指標！");
     }
     
   iDisplayInfo("Symbol", Symbol(), 1, 25, 30, 14, "Arial Bold", clrDodgerBlue);
   iDisplayInfo("TradeInfo", "最小下單額："+DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN), 2)+"手", 1, 5, 50, 9, "", clrOlive);
   
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(iSignalHandle != INVALID_HANDLE) IndicatorRelease(iSignalHandle);
   if(bandsHandle != INVALID_HANDLE) IndicatorRelease(bandsHandle);
   ObjectsDeleteAll(0, -1, OBJ_LABEL);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   iShowInfo();
   iTradeRule();
  }

//+------------------------------------------------------------------+
void iTradeRule()
  {
   int mySignal = iTradingSignals();
   
   if(SellGroupOrders == 0)
     {
      FirstTakeProfitTime = 0;
      SecondTicket = 0;
      ShockTicket = 0;
      CloseAll = false;
      DecreaseCnt = 0;
     }
     
   if(SecondTicket > 0 && iOrderProfitToPoint(SecondTicket) > 加倉第一次盈利點 && GetFirstTPTime == true)
     {
      FirstTakeProfitTime = TimeCurrent();
      GetFirstTPTime = false;
     }
     
   if(LastSignal == 4 && mySignal != 4) LastSignal = mySignal;
   if(LastSignal2 == 6 && mySignal != 6) LastSignal2 = mySignal;
   if(LastSignal3 == 7 && mySignal != 7) LastSignal3 = mySignal;
   
   // 設置止損
   if(SellGroupOrders > 0)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetString(POSITION_COMMENT) == 訂單注釋 && PositionGetInteger(POSITION_MAGIC) > 1)
           {
            double profitPts = iOrderProfitToPoint(ticket);
            bool cond1 = (止損加倉間隔時間先後 == true && profitPts > 加倉第一次盈利點);
            bool cond2 = (止損加倉間隔時間先後 == false && (TimeCurrent() - FirstTakeProfitTime) > 加倉時間間隔 && profitPts > 加倉第一次盈利點);
            
            if(cond1 || cond2)
              {
               double mySLPrice = iStopLossPrice(ticket);
               double currentSL = PositionGetDouble(POSITION_SL);
               double tp = PositionGetDouble(POSITION_TP);
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               
               if(固定止損 == true && currentSL == 0)
                 {
                  iDisplayInfo("TradeInfo", "賣出組訂單設置固定止損", 1, 5, 50, 9, "", clrOlive);
                  trade.PositionModify(ticket, mySLPrice, tp);
                 }
               else if(固定止損 == false && (mySLPrice < currentSL || currentSL == 0))
                 {
                  iDisplayInfo("TradeInfo", "賣出組訂單設置移動止損", 1, 5, 50, 9, "", clrOlive);
                  trade.PositionModify(ticket, mySLPrice, tp);
                 }
              }
           }
        }
     }
     
   // 信號3  減倉兩單盈利最小的空單，包括第一單
   if(mySignal == 3 && SellGroupOrders > 0 && DecreaseCnt < 2)
     {
      ulong minTicket = iMinProfitTicket();
      if(minTicket > 0 && PositionSelectByTicket(minTicket) && PositionGetDouble(POSITION_PROFIT) > 0)
        {
         iDisplayInfo("TradeInfo", "賣出組盈利最小的一單平倉", 1, 5, 50, 9, "", clrOlive);
         trade.PositionClose(minTicket);
         DecreaseCnt++;
        }
     }
     
   // 信號0  賣出組盈利則賣出組全平倉，否則賣出組盈利單平倉
   if(mySignal == 0)
     {
      if(SellGroupProfit > 0 && CloseAll == false) CloseAll = true;
      if(SellGroupProfit < 0)
        {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetString(POSITION_COMMENT) == 訂單注釋 && PositionGetDouble(POSITION_PROFIT) > 0)
              {
               iDisplayInfo("TradeInfo", "賣出組盈利單平倉", 1, 5, 50, 9, "", clrOlive);
               trade.PositionClose(ticket);
              }
           }
        }
     }
     
   // 全平倉
   if(CloseAll == true || (清倉開關 == true && mySignal == 0))
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetString(POSITION_COMMENT) == 訂單注釋)
           {
            iDisplayInfo("TradeInfo", "賣出組全部平倉", 1, 5, 50, 9, "", clrOlive);
            trade.PositionClose(ticket);
           }
        }
     }
     
   // 信號6,7  震盪空頭開倉
   bool mySendBoolean = iSendOrder();
   if(mySignal == 6 && LastSignal2 != 6 && mySendBoolean == true && 不開倉限制 == true)
     {
      iDisplayInfo("TradeInfo", "信號6新建震盪賣出持倉單", 1, 5, 50, 9, "", clrOlive);
      trade.SetExpertMagicNumber(1);
      trade.Sell(開倉量, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, 訂單注釋);
      ShockTicket = trade.ResultOrder();
      DecreaseCnt = 0;
      LastSignal2 = 6;
     }
   if(mySignal == 7 && LastSignal3 != 7 && mySendBoolean == true && 不開倉限制 == true)
     {
      iDisplayInfo("TradeInfo", "信號7新建震盪賣出持倉單", 1, 5, 50, 9, "", clrOlive);
      trade.SetExpertMagicNumber(1);
      trade.Sell(開倉量, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, 訂單注釋);
      ShockTicket = trade.ResultOrder();
      DecreaseCnt = 0;
      LastSignal3 = 7;
     }
     
   // 震盪賣出持倉單止盈
   if(ShockTicket > 0 && PositionSelectByTicket(ShockTicket) && PositionGetDouble(POSITION_TP) == 0)
     {
      iDisplayInfo("TradeInfo", "震盪賣出持倉單設置止盈", 1, 5, 50, 9, "", clrOlive);
      trade.PositionModify(ShockTicket, PositionGetDouble(POSITION_SL), NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - 震盪單止盈點 * _Point, _Digits));
     }
     
   // 信號5  趨空減倉
   if(mySignal == 5 && SellGroupOrders > 0 && DecreaseCnt == 0)
     {
      ulong minTicket = iMinProfitTicket();
      if(minTicket > 0 && PositionSelectByTicket(minTicket) && PositionGetDouble(POSITION_PROFIT) > 0)
        {
         iDisplayInfo("TradeInfo", "賣出組盈利最小的一單平倉", 1, 5, 50, 9, "", clrOlive);
         trade.PositionClose(minTicket);
         DecreaseCnt++;
        }
     }
     
   // 信號4  趨空加倉/開倉
   if(mySignal == 4)
     {
      if((不開倉限制 == true && SellGroupOrders == 0) || (不開倉限制 == true && mySendBoolean == true && SellGroupOrders > 0 && LastSignal != 4))
        {
         Magic = 0;
         trade.SetExpertMagicNumber(Magic);
         iDisplayInfo("TradeInfo", "新建第一賣出持倉單", 1, 5, 50, 9, "", clrOlive);
         trade.Sell(開倉量, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, 訂單注釋);
         LastSignal = 4;
         DecreaseCnt = 0;
        }
        
      if(SellGroupOrders == 1 && SellGroupLastTicket > 0 && PositionSelectByTicket(SellGroupLastTicket) && PositionGetInteger(POSITION_MAGIC) == 0 && TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME) > 第二單開倉時間間隔 && LastSignal == 4 && 不開倉限制 == true)
        {
         Magic = 2;
         trade.SetExpertMagicNumber(Magic);
         iDisplayInfo("TradeInfo", "新建第二賣出持倉單", 1, 5, 50, 9, "", clrOlive);
         trade.Sell(開倉量, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, 訂單注釋);
         SecondTicket = trade.ResultOrder();
         LastSignal = 4;
         DecreaseCnt = 0;
         GetFirstTPTime = true;
        }
        
      if(SellGroupOrders > 1 && SellGroupLastTicket > 0 && PositionSelectByTicket(SellGroupLastTicket) && PositionGetInteger(POSITION_MAGIC) >= 1 && PositionGetDouble(POSITION_SL) > 0 && TimeCurrent() - FirstTakeProfitTime > 加倉時間間隔 && LastSignal == 4 && 不開倉限制 == true && iOrderProfitToPoint(SellGroupLastTicket) > 加倉第一次盈利點 && iOrderProfitToPoint(SecondTicket) > 加倉第一次盈利點)
        {
         Magic++;
         trade.SetExpertMagicNumber(Magic);
         iDisplayInfo("TradeInfo", "新建第"+IntegerToString(Magic)+"賣出持倉單", 1, 5, 50, 9, "", clrOlive);
         trade.Sell(開倉量, Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_BID), 0, 0, 訂單注釋);
         LastSignal = 4;
         DecreaseCnt = 0;
        }
     }
  }

//+------------------------------------------------------------------+
int iTradingSignals()
  {
   double buf[1];
   if(CopyBuffer(iSignalHandle, 0, 0, 1, buf) > 0)
      return (int)buf[0];
   return 9;
  }

//+------------------------------------------------------------------+
bool iSendOrder()
  {
   if(SellGroupOrders > 0)
     {
      ulong maxLossTicket = iMaxLossTicket();
      if(maxLossTicket > 0)
        {
         int maxLossPts = iOrderProfitToPoint(maxLossTicket);
         if(maxLossPts < 0 && maxLossPts > -最大虧損單虧損點數) return false;
         if(maxLossPts >= 0) return false;
        }
        
      int lossCnt = 0;
      for(int i = 0; i < PositionsTotal(); i++)
        {
         ulong t = PositionGetTicket(i);
         if(t > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetString(POSITION_COMMENT) == 訂單注釋 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
           {
            if(PositionGetDouble(POSITION_PROFIT) < 0) lossCnt++;
           }
        }
      if(lossCnt >= 虧損單最大數量) return false;
      
      ulong minProfTicket = iMinProfitTicket();
      if(minProfTicket > 0)
        {
         if(iOrderProfitToPoint(minProfTicket) < 最小盈利單盈利點數) return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
double iStopLossPrice(ulong ticket)
  {
   double slPrice = 0;
   int currentLossStop = 止損點;
   if(currentLossStop == 0)
     {
      double up[1], down[1];
      if(CopyBuffer(bandsHandle, 1, 0, 1, up) > 0 && CopyBuffer(bandsHandle, 2, 0, 1, down) > 0)
        {
         currentLossStop = (int)(((up[0] - down[0]) / 2) / _Point);
        }
     }
     
   if(ticket > 0 && PositionSelectByTicket(ticket))
     {
      double sl = PositionGetDouble(POSITION_SL);
      if(sl == 0)
        {
         slPrice = PositionGetDouble(POSITION_PRICE_OPEN) + currentLossStop * _Point;
        }
      else
        {
         slPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + currentLossStop * _Point;
        }
     }
   return NormalizeDouble(slPrice, _Digits);
  }

//+------------------------------------------------------------------+
int iOrderProfitToPoint(ulong ticket)
  {
   if(ticket > 0 && PositionSelectByTicket(ticket))
     {
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      if(tickValue > 0 && volume > 0)
         return (int)((profit / tickValue) / volume);
     }
   return 0;
  }

//+------------------------------------------------------------------+
ulong iMaxLossTicket()
  {
   ulong minTicket = 0;
   double minProfit = 0;
   bool first = true;
   
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetString(POSITION_COMMENT) == 訂單注釋 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(first || p < minProfit)
           {
            minProfit = p;
            minTicket = t;
            first = false;
           }
        }
     }
   return minTicket;
  }

//+------------------------------------------------------------------+
ulong iMinProfitTicket()
  {
   ulong minTicket = 0;
   double minProfit = 0;
   bool first = true;
   
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetString(POSITION_COMMENT) == 訂單注釋 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(p > 0)
           {
            if(first || p < minProfit)
              {
               minProfit = p;
               minTicket = t;
               first = false;
              }
           }
        }
     }
   return minTicket;
  }

//+------------------------------------------------------------------+
void iShowInfo()
  {
   SellGroupOrders = 0;
   SellGroupFirstTicket = 0;
   SellGroupLastTicket = 0;
   SellGroupLots = 0;
   SellGroupProfit = 0;
   
   datetime firstTime = 0, lastTime = 0;
   bool first = true;
   
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetString(POSITION_COMMENT) == 訂單注釋 && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         SellGroupOrders++;
         SellGroupLots += PositionGetDouble(POSITION_VOLUME);
         SellGroupProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         
         datetime time = (datetime)PositionGetInteger(POSITION_TIME);
         if(first)
           {
            firstTime = time;
            lastTime = time;
            SellGroupFirstTicket = ticket;
            SellGroupLastTicket = ticket;
            first = false;
           }
         else
           {
            if(time < firstTime) { firstTime = time; SellGroupFirstTicket = ticket; }
            if(time > lastTime) { lastTime = time; SellGroupLastTicket = ticket; }
           }
        }
     }
     
   iDisplayInfo("Symbol-SellGroup", "賣出組", 1, 5, 70, 12, "Arial", clrGreen);
   iDisplayInfo("Symbol-Bid", DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_BID), _Digits), 1, 5, 90, 12, "Arial", clrGreen);
   iDisplayInfo("SellOrders", IntegerToString(SellGroupOrders), 1, 10, 110, 10, "Arial", (SellGroupProfit >= 0) ? clrGreen : clrRed);
   iDisplayInfo("SellGroupLots", DoubleToString(SellGroupLots, 2), 1, 10, 125, 10, "Arial", (SellGroupProfit >= 0) ? clrGreen : clrRed);
   iDisplayInfo("SellGroupProfit", DoubleToString(SellGroupProfit, 2), 1, 10, 140, 10, "Arial", (SellGroupProfit >= 0) ? clrGreen : clrRed);
  }

//+------------------------------------------------------------------+
void iDisplayInfo(string LableName, string LableDoc, int Corner, int LableX, int LableY, int DocSize, string DocStyle, color DocColor)
  {
   if(Corner == -1) return;
   ObjectCreate(0, LableName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, LableName, OBJPROP_TEXT, LableDoc);
   ObjectSetInteger(0, LableName, OBJPROP_CORNER, Corner);
   ObjectSetInteger(0, LableName, OBJPROP_XDISTANCE, LableX);
   ObjectSetInteger(0, LableName, OBJPROP_YDISTANCE, LableY);
   ObjectSetInteger(0, LableName, OBJPROP_FONTSIZE, DocSize);
   if(DocStyle != "") ObjectSetString(0, LableName, OBJPROP_FONT, DocStyle);
   ObjectSetInteger(0, LableName, OBJPROP_COLOR, DocColor);
  }
//+------------------------------------------------------------------+
