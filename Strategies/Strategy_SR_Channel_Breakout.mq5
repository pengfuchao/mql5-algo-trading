//+------------------------------------------------------------------+
//|                              Strategy_SR_Channel_Breakout.mq5    |
//|                                                                  |
//|  對接 Indicators/Support_Resistance_Channels.mq5 的突破 EA。      |
//|  讀取指標的 Resistance/Support Broken 訊號 buffer (已收盤棒)，    |
//|  以順勢突破方向進場，ATR 止損 + RR 止盈，風險% 動態手數。         |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- 必須與指標的 enum 數值一致
enum ENUM_SR_SOURCE
  {
   SRC_HIGHLOW = 0,   // High/Low
   SRC_CLOSEOPEN = 1  // Close/Open
  };

//=== 指標參數 (順序必須與 Support_Resistance_Channels.mq5 的 input 宣告一致) ===
input group "S/R Indicator"
input string          InpIndicatorName  = "Support_Resistance_Channels"; // iCustom 路徑 (相對 MQL5\Indicators)
input int             InpPivotPeriod    = 10;            // Pivot Period
input ENUM_SR_SOURCE  InpSourceMode     = SRC_HIGHLOW;   // Source
input int             InpChannelWidthPct= 5;             // Max Channel Width %
input int             InpMinStrength    = 1;             // Minimum Strength
input int             InpMaxNumSR       = 6;             // Maximum Number of S/R
input int             InpLoopback       = 290;           // Loopback Period

//=== 交易設定 ===
input group "Trade"
input ulong           InpMagic          = 770010;        // Magic Number
input ulong           InpDeviation      = 20;            // 允許滑點 (points)
input double          InpMaxSpreadPts   = 30.0;          // 最大點差 (points)，0=不檢查
input bool            InpCloseOnReverse = true;          // 反向訊號先平倉
input bool            InpOnePosition    = true;          // 同方向僅持一張
input int             InpMaxPositions   = 5;             // 同方向最大持倉數 (OnePosition=false 時生效)
input bool            InpTradeOnFirstBar= false;         // 掛載後是否立即依上一根訊號交易

//=== 倉位與風險 ===
input group "Sizing & Risk"
input bool            InpUseRiskSizing  = true;          // 以風險% + SL 距離計算手數
input double          InpRiskPercent    = 1.0;           // 每筆風險佔淨值 %
input double          InpFixedLots      = 0.10;          // 固定手數 (UseRiskSizing=false)
input int             InpATRPeriod      = 14;            // ATR 週期 (止損距離)
input double          InpSLMultiple     = 1.5;           // 止損 = ATR × 此倍數
input double          InpTPRatio        = 2.0;           // 止盈 = SL 距離 × 此倍數 (RR)，0=不設

//--- 全域
CTrade   trade;
int      srHandle  = INVALID_HANDLE;
int      atrHandle = INVALID_HANDLE;
datetime lastBar   = 0;
ENUM_ACCOUNT_MARGIN_MODE marginMode = ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;

//+------------------------------------------------------------------+
//| 手數正規化                                                       |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = (minLot > 0 ? minLot : 0.01);

   lots = MathFloor(lots / step) * step;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   return lots;
  }

//+------------------------------------------------------------------+
//| 價格對齊 broker tick size (避免 Invalid price)                    |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0)
      return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
  }

//+------------------------------------------------------------------+
//| 依 SL 距離與風險% 計算手數                                        |
//|   回傳 <= 0 表示「不應交易」(風險設定為 0，或最小手數已超過上限)  |
//+------------------------------------------------------------------+
double LotsByRisk(double slDistance)
  {
   if(!InpUseRiskSizing)
      return NormalizeLots(InpFixedLots);

   if(InpRiskPercent <= 0.0)
     {
      Print("InpRiskPercent<=0，跳過進場");
      return 0.0;
     }

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(slDistance <= 0 || tickValue <= 0 || tickSize <= 0)
     {
      Print("tick value/size 或 SL 距離無效，回退固定手數");
      return NormalizeLots(InpFixedLots);
     }

   double valuePerPricePerLot = tickValue / tickSize;       // 每 1.0 價格波動每手金額
   double riskPerLot = slDistance * valuePerPricePerLot;    // 每手在 SL 距離下的金額風險
   if(riskPerLot <= 0)
      return NormalizeLots(InpFixedLots);

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = (InpRiskPercent / 100.0) * equity;

   double lots       = NormalizeLots(riskAmount / riskPerLot);
   double actualRisk = lots * riskPerLot;
   // 最小手數/步進向上夾擠導致實際風險超過設定上限時，停止交易而非放大風險
   if(actualRisk > riskAmount * 1.0001)
     {
      PrintFormat("最小手數 %.2f 風險 %.2f 超過上限 %.2f (%.2f%% equity)，略過進場",
                  lots, actualRisk, riskAmount, InpRiskPercent);
      return 0.0;
     }
   return lots;
  }

//+------------------------------------------------------------------+
//| 計算本 EA (symbol+magic) 的多空持倉數                            |
//+------------------------------------------------------------------+
void CountPositions(int &buyCount, int &sellCount)
  {
   buyCount = 0; sellCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)  buyCount++;
      if(type == POSITION_TYPE_SELL) sellCount++;
     }
  }

//+------------------------------------------------------------------+
//| 平掉本 EA 指定方向的所有持倉                                      |
//|   回傳 true 表示全部成功送出且未被拒，false 表示至少一筆失敗      |
//+------------------------------------------------------------------+
bool CloseByType(const ENUM_POSITION_TYPE wantType)
  {
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      if(PositionGetInteger(POSITION_TYPE) != wantType) continue;
      if(!trade.PositionClose(ticket))
        {
         allClosed = false;
         PrintFormat("PositionClose 失敗 ticket=%I64u: retcode=%u %s",
                     ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }
   return allClosed;
  }

//+------------------------------------------------------------------+
//| 交易環境檢查 (terminal/account/symbol 是否允許交易、是否開盤)     |
//+------------------------------------------------------------------+
bool CanTrade()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))         return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))                   return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))           return false;
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| 開倉前保證金檢查                                                  |
//+------------------------------------------------------------------+
bool HasEnoughMargin(const ENUM_ORDER_TYPE type, const double lots, const double price)
  {
   double margin = 0.0;
   if(!OrderCalcMargin(type, _Symbol, lots, price, margin))
      return true; // 無法計算時不阻擋 (交由 broker 端判斷)
   return (AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= margin);
  }

//+------------------------------------------------------------------+
//| 下單結果記錄 (L1：驗證 retcode/deal/order)                        |
//+------------------------------------------------------------------+
void LogTradeResult(const string ctx)
  {
   uint rc = trade.ResultRetcode();
   if(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED)
      PrintFormat("%s 成功: deal=%I64u order=%I64u vol=%.2f price=%.5f",
                  ctx, trade.ResultDeal(), trade.ResultOrder(), trade.ResultVolume(), trade.ResultPrice());
   else
      PrintFormat("%s 未完成: retcode=%u %s", ctx, rc, trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//| 新 K 線判斷                                                      |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t[1];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, t) < 1) return false;
   if(t[0] != lastBar) { lastBar = t[0]; return true; }
   return false;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);

   srHandle = iCustom(_Symbol, _Period, InpIndicatorName,
                      InpPivotPeriod, InpSourceMode, InpChannelWidthPct,
                      InpMinStrength, InpMaxNumSR, InpLoopback);
   if(srHandle == INVALID_HANDLE)
     {
      PrintFormat("無法載入指標 '%s' (請確認已編譯且路徑正確), error=%d",
                  InpIndicatorName, GetLastError());
      return(INIT_FAILED);
     }

   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("無法載入 ATR 指標！");
      return(INIT_FAILED);
     }

   marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   PrintFormat("帳戶 margin mode = %s", EnumToString(marginMode));

   // M1：預設等待下一根新 K 棒才交易，避免掛載當下吃上一根 stale signal
   if(InpTradeOnFirstBar)
      lastBar = 0;
   else
     {
      datetime t[1];
      lastBar = (CopyTime(_Symbol, _Period, 0, 1, t) == 1) ? t[0] : 0;
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(srHandle  != INVALID_HANDLE) IndicatorRelease(srHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // 僅在新 K 棒評估 (使用已收盤棒訊號，避免盤中 repaint)
   if(!IsNewBar()) return;

   // M5：指標尚未計算完成前不讀取，避免讀到未填值
   if(BarsCalculated(srHandle) < 2 || BarsCalculated(atrHandle) < 2) return;

   // 讀取指標訊號 (shift=1 已收盤棒)：Buffer 2=ResBroken, Buffer 3=SupBroken
   double resArr[1], supArr[1];
   if(CopyBuffer(srHandle, 2, 1, 1, resArr) < 1) return;
   if(CopyBuffer(srHandle, 3, 1, 1, supArr) < 1) return;
   bool buySig  = (resArr[0] > 0.0);   // 壓力向上突破 → 做多
   bool sellSig = (supArr[0] > 0.0);   // 支撐向下跌破 → 做空
   if(!buySig && !sellSig) return;
   if(buySig && sellSig)   return;     // 同棒同時觸發 (罕見)，視為不明確不交易

   // L6：交易環境檢查
   if(!CanTrade()) { Print("目前不允許交易 (terminal/account/symbol/session)，略過"); return; }

   // ATR (採用已收盤棒)
   double atrArr[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atrArr) < 1) return;
   double atr = atrArr[0];
   if(atr <= 0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return;
   double spread = ask - bid;

   // 點差過濾
   if(InpMaxSpreadPts > 0)
     {
      double spreadPts = spread / _Point;
      if(spreadPts > InpMaxSpreadPts)
        {
         PrintFormat("點差 %.1f > 上限 %.1f，略過進場", spreadPts, InpMaxSpreadPts);
         return;
        }
     }

   // M2：SL 距離須讓 SL 與「對應側價格」距離 >= stopsLevel，故下限納入 spread
   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double minStop = stopsLevel + spread;
   double slDist  = MathMax(atr * InpSLMultiple, minStop);
   if(slDist <= 0) return;

   int buyCount, sellCount;
   CountPositions(buyCount, sellCount);
   int maxSameDir = InpOnePosition ? 1 : MathMax(1, InpMaxPositions); // L5：同方向上限

   //=== 做多 ===
   if(buySig)
     {
      // H1：反向倉須確認全部關閉才進場
      if(InpCloseOnReverse && sellCount > 0)
        {
         CloseByType(POSITION_TYPE_SELL);
         CountPositions(buyCount, sellCount);
         if(sellCount > 0) { Print("反向(空)倉未全部關閉，略過本次進場"); return; }
        }
      if(buyCount >= maxSameDir) return;

      double sl = NormalizePrice(ask - slDist);
      double realDist = ask - sl;                                   // 量化後真實 SL 距離 → 用於 sizing
      double tpDist = (InpTPRatio > 0) ? MathMax(slDist * InpTPRatio, stopsLevel) : 0.0;
      double tp = (tpDist > 0) ? NormalizePrice(ask + tpDist) : 0.0;
      double lots = LotsByRisk(realDist);
      if(lots <= 0) return;                                         // H2：風險超限/設定為 0 → 不交易
      if(!HasEnoughMargin(ORDER_TYPE_BUY, lots, ask)) { Print("可用保證金不足，略過做多"); return; }

      trade.Buy(lots, _Symbol, 0.0, sl, tp, "SRchan breakout buy");
      LogTradeResult("Buy");
     }
   //=== 做空 ===
   else if(sellSig)
     {
      if(InpCloseOnReverse && buyCount > 0)
        {
         CloseByType(POSITION_TYPE_BUY);
         CountPositions(buyCount, sellCount);
         if(buyCount > 0) { Print("反向(多)倉未全部關閉，略過本次進場"); return; }
        }
      if(sellCount >= maxSameDir) return;

      double sl = NormalizePrice(bid + slDist);
      double realDist = sl - bid;
      double tpDist = (InpTPRatio > 0) ? MathMax(slDist * InpTPRatio, stopsLevel) : 0.0;
      double tp = (tpDist > 0) ? NormalizePrice(bid - tpDist) : 0.0;
      double lots = LotsByRisk(realDist);
      if(lots <= 0) return;
      if(!HasEnoughMargin(ORDER_TYPE_SELL, lots, bid)) { Print("可用保證金不足，略過做空"); return; }

      trade.Sell(lots, _Symbol, 0.0, sl, tp, "SRchan breakout sell");
      LogTradeResult("Sell");
     }
  }

//+------------------------------------------------------------------+
//| 自訂最佳化評分：恢復因子 × 獲利因子 × √交易筆數                  |
//+------------------------------------------------------------------+
double OnTester()
  {
   double netProfit    = TesterStatistics(STAT_PROFIT);
   double ddPercent    = TesterStatistics(STAT_EQUITYDD_PERCENT);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery     = TesterStatistics(STAT_RECOVERY_FACTOR);
   int    trades       = (int)TesterStatistics(STAT_TRADES);

   if(trades < 30 || netProfit <= 0.0 || ddPercent <= 0.0)
      return 0.0;

   double score = recovery * profitFactor * MathSqrt((double)trades);
   if(score < 0.0 || !MathIsValidNumber(score)) score = 0.0;
   return score;
  }
//+------------------------------------------------------------------+
