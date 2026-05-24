//+------------------------------------------------------------------+
//|                                           EA_ML_SuperTrend.mq5  |
//|                        Hammad Dilber / Quantitative Expert      |
//|                         https://github.com/pengfuchao/            |
//+------------------------------------------------------------------+
#property copyright "Hammad Dilber / Quantitative Expert"
#property link      "https://github.com/pengfuchao/"
#property version   "1.00"
#property strict

// Include standard MT5 trade libraries
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

// Instantiate trade execution classes
CTrade         trade;
CSymbolInfo    g_symbol;
CPositionInfo  position;

//==========================================================================
// ENUMS
//==========================================================================
enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,   // Fixed Lots
   LOT_RISK  = 1,   // Risk Percent based on ATR Stop
   LOT_CONF  = 2    // Confidence-scaled Lots
};

enum ENUM_EA_SIGNAL_MODE
{
   EA_SignalReversal  = 0,  // Reversal Mode
   EA_SignalBreakout  = 1   // Breakout Mode
};

//==========================================================================
// UTILITIES
//==========================================================================
double Clamp(double v,double lo,double hi){return MathMax(lo,MathMin(hi,v));}

//==========================================================================
// INPUT PARAMETERS
//==========================================================================
sinput string     Section_ST         = "=== ML SUPERTREND INDICATOR SETTINGS ===";
input string      InpIndicatorPath   = "Strategies\\ML_SuperTrend"; // Indicator Path (relative to MQL5\\Indicators)
input ENUM_EA_SIGNAL_MODE InpSignalMode = EA_SignalReversal;      // Signal Mode
input double      InpMultiplier      = 1.4;                         // SuperTrend Multiplier
input int         InpATRPeriod       = 24;                         // SuperTrend ATR Period
input int         InpDialK           = 10;                         // Optimizer Dial K (Reactivity)
input bool        InpEnableAdaptive  = true;                       // Enable Dynamic Auto-Tuning

sinput string     Section_Trade      = "=== EA TRADING & POSITION SETTINGS ===";
input ENUM_LOT_MODE InpLotMode       = LOT_RISK;                   // Position Sizing Mode
input double      InpFixedLot        = 0.1;                        // Fixed Lot Size (for Fixed Mode)
input double      InpRiskPercent     = 1.0;                        // Risk % of Equity per Trade (for Risk Mode)
input double      InpConfLotMax      = 0.5;                        // Max Lot Size for 100% Confidence (for Confidence Mode)
input int         InpMagicNumber     = 888123;                     // Magic Number for Order ID
input int         InpSlippage        = 10;                         // Max slippage allowed in points

sinput string     Section_Risk       = "=== RISK & TRAILING SETTINGS ===";
input double      InpSLATRMult       = 1.5;                        // Initial Stop Loss Multiplier (xATR)
input double      InpTPATRMult       = 3.0;                        // Initial Take Profit Multiplier (xATR)
input bool        InpUseTrailingStop = true;                       // Trailing Stop based on SuperTrend Line
input double      InpMinATR          = 0.0001;                     // Minimum ATR floor (prevents extreme sizing)

//==========================================================================
// GLOBALS
//==========================================================================
int      h_ml_st = INVALID_HANDLE;  // Custom Indicator Handle
datetime g_lastBarTime = 0;         // Tracks new bar transitions

//==========================================================================
// OnInit
//==========================================================================
int OnInit()
{
   // 1. Initialize Symbol Info
   if(!g_symbol.Name(_Symbol))
   {
      Print("EA_ML_SuperTrend: Failed to initialize symbol information.");
      return INIT_FAILED;
   }
   
   // 2. Set Magic Number for Trade Execution
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   
   // 3. Load Custom Indicator ML_SuperTrend
   // Note: We pass the indicator parameters in the exact order they appear in the indicator inputs
   h_ml_st = iCustom(_Symbol, _Period, InpIndicatorPath,
                     InpSignalMode,       // GROUP 1: Signal Type
                     false,               // GROUP 1: Require Fresh Pivot (false)
                     10,                  // GROUP 1: Signal Spacing (10)
                     30,                  // GROUP 2: Lookback Window (30)
                     InpATRPeriod,        // GROUP 2: Smoothing Period
                     InpMultiplier,       // GROUP 2: Band Width
                     7,                   // GROUP 2: Price Basis (SRC_HLCC4)
                     true,                // GROUP 2: True Range Mode (RMA)
                     true,                // GROUP 3: RSI Active (true)
                     14,                  // GROUP 3: RSI Length (14)
                     50,                  // GROUP 3: Hot Zone Memory (50)
                     50,                  // GROUP 3: Cold Zone Memory (50)
                     3,                   // GROUP 4: Sample Depth (3)
                     1.2,                 // GROUP 4: Surge Threshold (1.2)
                     false,               // GROUP 4: Require Surge (false)
                     false,               // GROUP 5: Key Levels Only (false)
                     4.5,                 // GROUP 5: Key Level Depth (4.5)
                     InpDialK,            // GROUP 6: Dial K
                     true,                // GROUP 6: Micro-Batch Processing (true)
                     true,                // GROUP 6: Live Pressure Sensor (true)
                     InpEnableAdaptive    // GROUP 7: Enable Adaptive Auto-Tune
                     );
                     
   if(h_ml_st == INVALID_HANDLE)
   {
      Print("EA_ML_SuperTrend: FAILED to load custom indicator: ", InpIndicatorPath);
      Alert("EA Init Failed! Please verify that ML_SuperTrend.ex5 is compiled and located under MQL5\\Indicators\\", InpIndicatorPath);
      return INIT_FAILED;
   }
   
   Print("EA_ML_SuperTrend: Loaded custom indicator successfully. Magic Number: ", InpMagicNumber);
   return INIT_SUCCEEDED;
}

//==========================================================================
// OnDeinit
//==========================================================================
void OnDeinit(const int reason)
{
   if(h_ml_st != INVALID_HANDLE)
   {
      IndicatorRelease(h_ml_st);
   }
   Print("EA_ML_SuperTrend: Expert Advisor deinitialized.");
}

//==========================================================================
// OnTick
//==========================================================================
void OnTick()
{
   // 1. Enforce Trailing Stop on every Tick
   if(InpUseTrailingStop)
   {
      ManageTrailingStop();
   }

   // 2. Enforce New Bar execution (Signal checking)
   // We execute strictly on Bar 1 (newly closed bar) to prevent repainting/false execution mid-bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime) return; // Not a new bar yet
   
   // Handle synchronization on first run
   if(g_lastBarTime == 0)
   {
      g_lastBarTime = currentBarTime;
      return;
   }
   
   // A new bar has officially opened. Update g_lastBarTime
   g_lastBarTime = currentBarTime;
   
   // 3. Read Indicator Signal Buffers at Index 1 (completed bar)
   double buyBuf[], sellBuf[], confBuf[], stBullBuf[], stBearBuf[];
   
   if(CopyBuffer(h_ml_st, 2, 1, 1, buyBuf) <= 0) return;
   if(CopyBuffer(h_ml_st, 3, 1, 1, sellBuf) <= 0) return;
   if(CopyBuffer(h_ml_st, 4, 1, 1, confBuf) <= 0) return;
   
   double buySignal  = buyBuf[0];
   double sellSignal = sellBuf[0];
   double confidence = confBuf[0];
   
   // Get standard ATR value to calculate TP/SL distances
   // We read it from the indicator's internal ATR buffer if possible, or build a local iATR
   // For robust execution, we retrieve the current ATR using the terminal's ATR indicator handle
   static int h_atr_local = INVALID_HANDLE;
   if(h_atr_local == INVALID_HANDLE)
   {
      h_atr_local = iATR(_Symbol, _Period, InpATRPeriod);
   }
   double atrBuf[];
   double currentATR = InpMinATR;
   if(h_atr_local != INVALID_HANDLE && CopyBuffer(h_atr_local, 0, 1, 1, atrBuf) > 0)
   {
      currentATR = MathMax(atrBuf[0], InpMinATR);
   }

   // 4. Signal Execution
   if(buySignal > 0)
   {
      Print("EA_ML_SuperTrend: BUY Signal detected! Confidence: ", DoubleToString(confidence, 1), "%");
      
      // Close active short positions first (Reversal Trade)
      ClosePositions(POSITION_TYPE_SELL);
      
      // Check if we are already holding buy positions to avoid duplicate trades
      if(CountOpenPositions(POSITION_TYPE_BUY) == 0)
      {
         double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double slPrice  = askPrice - (InpSLATRMult * currentATR);
         double tpPrice  = askPrice + (InpTPATRMult * currentATR);
         
         double lotSize = CalculateLotSize(InpSLATRMult * currentATR, confidence);
         
         if(lotSize > 0)
         {
            trade.Buy(lotSize, _Symbol, askPrice, slPrice, tpPrice, "MLST Long (Conf: " + DoubleToString(confidence,0) + "%)");
         }
      }
   }
   else if(sellSignal > 0)
   {
      Print("EA_ML_SuperTrend: SELL Signal detected! Confidence: ", DoubleToString(confidence, 1), "%");
      
      // Close active long positions first (Reversal Trade)
      ClosePositions(POSITION_TYPE_BUY);
      
      // Check if we are already holding sell positions to avoid duplicate trades
      if(CountOpenPositions(POSITION_TYPE_SELL) == 0)
      {
         double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double slPrice  = bidPrice + (InpSLATRMult * currentATR);
         double tpPrice  = bidPrice - (InpTPATRMult * currentATR);
         
         double lotSize = CalculateLotSize(InpSLATRMult * currentATR, confidence);
         
         if(lotSize > 0)
         {
            trade.Sell(lotSize, _Symbol, bidPrice, slPrice, tpPrice, "MLST Short (Conf: " + DoubleToString(confidence,0) + "%)");
         }
      }
   }
}

//==========================================================================
// TRAILING STOP POSITION MANAGEMENT
//==========================================================================
void ManageTrailingStop()
{
   double stBullBuf[], stBearBuf[];
   
   // Read SuperTrend line buffers on current active K-bar (index 0) to trail dynamically
   if(CopyBuffer(h_ml_st, 0, 0, 1, stBullBuf) <= 0) return;
   if(CopyBuffer(h_ml_st, 1, 0, 1, stBearBuf) <= 0) return;
   
   double stBull = stBullBuf[0];
   double stBear = stBearBuf[0];
   
   // Iterate through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         // Verify position belongs to this EA and matches the symbol
         if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
         {
            double entryPrice = position.PriceOpen();
            double currentSL  = position.StopLoss();
            
            // ── Trailing Long Positions ──────────────────────────
            if(position.PositionType() == POSITION_TYPE_BUY)
            {
               // If SuperTrend Bull line is active and is higher than the current SL (or no SL is set)
               if(stBull > 0 && (currentSL < stBull || currentSL == 0))
               {
                  // Modify Position Stop Loss
                  if(stBull < SymbolInfoDouble(_Symbol, SYMBOL_BID) - g_symbol.StopsLevel() * _Point)
                  {
                     trade.PositionModify(position.Ticket(), NormalizeDouble(stBull, _Digits), position.TakeProfit());
                  }
               }
            }
            // ── Trailing Short Positions ──────────────────────────
            else if(position.PositionType() == POSITION_TYPE_SELL)
            {
               // If SuperTrend Bear line is active and is lower than the current SL (or no SL is set)
               if(stBear > 0 && (currentSL > stBear || currentSL == 0))
                  {
                  // Modify Position Stop Loss
                  if(stBear > SymbolInfoDouble(_Symbol, SYMBOL_ASK) + g_symbol.StopsLevel() * _Point)
                  {
                     trade.PositionModify(position.Ticket(), NormalizeDouble(stBear, _Digits), position.TakeProfit());
                  }
               }
            }
         }
      }
   }
}

//==========================================================================
// MONEY MANAGEMENT LOT SIZING
//==========================================================================
double CalculateLotSize(double slDistance, double confidence)
{
   double lot = InpFixedLot;
   
   if(InpLotMode == LOT_RISK)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskValue = balance * (InpRiskPercent / 100.0);
      
      // Get tick value and tick size safely
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize > 0 && slDistance > 0 && tickValue > 0)
      {
         // Standard quantitative formula: Lot = RiskValue / (SL_distance_in_points * TickValue)
         lot = riskValue / ((slDistance / tickSize) * tickValue);
      }
      else
      {
         lot = InpFixedLot;
      }
   }
   else if(InpLotMode == LOT_CONF)
   {
      double confScale = Clamp(confidence / 100.0, 0.1, 1.0);
      lot = InpConfLotMax * confScale;
   }
   
   // Enforce Broker minimum/maximum lot parameters
   double minLot = g_symbol.LotsMin();
   double maxLot = g_symbol.LotsMax();
   double lotStep = g_symbol.LotsStep();
   
   if(lotStep > 0)
   {
      lot = MathRound(lot / lotStep) * lotStep;
   }
   if(minLot > 0 && maxLot > 0)
   {
      lot = Clamp(lot, minLot, maxLot);
   }
   
   return lot;
}

//==========================================================================
// TRADE UTILITIES
//==========================================================================
int CountOpenPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && 
            position.Magic() == InpMagicNumber && 
            position.PositionType() == type)
         {
            count++;
         }
      }
   }
   return count;
}

void ClosePositions(ENUM_POSITION_TYPE type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && 
            position.Magic() == InpMagicNumber && 
            position.PositionType() == type)
         {
            trade.PositionClose(position.Ticket(), InpSlippage);
         }
      }
   }
}
