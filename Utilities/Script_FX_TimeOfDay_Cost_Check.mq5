//+------------------------------------------------------------------+
//|                    Script_FX_TimeOfDay_Cost_Check.mq5            |
//|                                                                  |
//|  Phase 0 cost gate for FX Time-of-Day Effect research.            |
//|  This standalone script does not trade. It samples the current    |
//|  spread, converts commission/slippage to pips, writes one CSV row |
//|  under MQL5/Files, and prints a GO/BORDERLINE/KILL decision.       |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"
#property script_show_inputs

input string InpSymbol                         = "EURUSD"; // Symbol to inspect
input int    InpSamples                        = 30;       // Spread samples to collect
input int    InpSampleIntervalMs               = 1000;     // Delay between samples
input double InpCommissionPerLotRoundTurn      = 0.0;      // Account currency per 1.0 lot round turn
input double InpExpectedSlippagePipsRoundTurn  = 0.2;      // Expected round-turn slippage in pips
input bool   InpWriteCsv                       = true;     // Write one evidence row to MQL5/Files

//+------------------------------------------------------------------+
string Trim(const string value)
  {
   string result = value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
  }

double PipSize(const string symbol)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

string SafeFilePart(const string value)
  {
   string out = value;
   StringReplace(out, ".", "_");
   StringReplace(out, "#", "_");
   StringReplace(out, "/", "_");
   StringReplace(out, "\\", "_");
   StringReplace(out, ":", "_");
   return out;
  }

string TimeFilePart(const datetime value)
  {
   string out = TimeToString(value, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   StringReplace(out, ".", "");
   StringReplace(out, ":", "");
   StringReplace(out, " ", "_");
   return out;
  }

double Average(const double &values[])
  {
   int n = ArraySize(values);
   if(n <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < n; i++)
      sum += values[i];
   return sum / n;
  }

double Median(const double &values[])
  {
   int n = ArraySize(values);
   if(n <= 0)
      return 0.0;

   double sorted[];
   ArrayResize(sorted, n);
   for(int i = 0; i < n; i++)
      sorted[i] = values[i];
   ArraySort(sorted);

   if((n % 2) == 1)
      return sorted[n / 2];
   return 0.5 * (sorted[n / 2 - 1] + sorted[n / 2]);
  }

double MinValue(const double &values[])
  {
   int n = ArraySize(values);
   if(n <= 0)
      return 0.0;

   double result = values[0];
   for(int i = 1; i < n; i++)
      result = MathMin(result, values[i]);
   return result;
  }

double MaxValue(const double &values[])
  {
   int n = ArraySize(values);
   if(n <= 0)
      return 0.0;

   double result = values[0];
   for(int i = 1; i < n; i++)
      result = MathMax(result, values[i]);
   return result;
  }

double PipValuePerLot(const string symbol, const double pip)
  {
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0 || pip <= 0.0)
      return 0.0;
   return tickValue * pip / tickSize;
  }

string DecisionLabel(const double oneSideCostPips)
  {
   if(oneSideCostPips <= 0.8)
      return "GO";
   if(oneSideCostPips <= 1.2)
      return "BORDERLINE";
   if(oneSideCostPips < 1.7)
      return "NO_GO_COST_TOO_HIGH";
   return "KILL";
  }

string DecisionNote(const double oneSideCostPips)
  {
   if(oneSideCostPips <= 0.8)
      return "cost gate passes; Phase 1 implementation is economically plausible";
   if(oneSideCostPips <= 1.2)
      return "thin edge; prototype only if ECN/demo-forward evidence is still desired";
   if(oneSideCostPips < 1.7)
      return "cost likely consumes most of the gross edge; do not build unless cost improves";
   return "cost reaches or exceeds estimated gross edge; do not build";
  }

void WriteCsv(const string symbol,
              const int sampleCount,
              const double spreadAvg,
              const double spreadMedian,
              const double spreadMin,
              const double spreadMax,
              const double pipValue,
              const double commissionRoundTurnPips,
              const double slippageRoundTurnPips,
              const double roundTurnCostPips,
              const double oneSideCostPips,
              const string decision)
  {
   string fileName = StringFormat("FX_TimeOfDay_Cost_Check_%s_%s.csv",
                                  SafeFilePart(symbol),
                                  TimeFilePart(TimeCurrent()));
   int handle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("CSV write failed: %s, error=%d", fileName, GetLastError());
      return;
     }

   FileWrite(handle,
             "timestamp_server",
             "symbol",
             "account_currency",
             "samples",
             "spread_avg_pips",
             "spread_median_pips",
             "spread_min_pips",
             "spread_max_pips",
             "pip_value_per_lot",
             "commission_roundturn_pips",
             "slippage_roundturn_pips",
             "roundturn_cost_pips",
             "one_side_equivalent_cost_pips",
             "decision");
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
             symbol,
             AccountInfoString(ACCOUNT_CURRENCY),
             sampleCount,
             DoubleToString(spreadAvg, 3),
             DoubleToString(spreadMedian, 3),
             DoubleToString(spreadMin, 3),
             DoubleToString(spreadMax, 3),
             DoubleToString(pipValue, 4),
             DoubleToString(commissionRoundTurnPips, 3),
             DoubleToString(slippageRoundTurnPips, 3),
             DoubleToString(roundTurnCostPips, 3),
             DoubleToString(oneSideCostPips, 3),
             decision);
   FileClose(handle);
   PrintFormat("CSV written to MQL5/Files/%s", fileName);
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   string symbol = Trim(InpSymbol);
   if(symbol == "")
      symbol = _Symbol;

   if(InpSamples <= 0 || InpSampleIntervalMs < 0)
     {
      Print("Invalid inputs: InpSamples must be > 0 and InpSampleIntervalMs must be >= 0.");
      return;
     }
   if(InpCommissionPerLotRoundTurn < 0.0 || InpExpectedSlippagePipsRoundTurn < 0.0)
     {
      Print("Invalid inputs: commission and slippage assumptions must be non-negative.");
      return;
     }
   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("SymbolSelect failed for %s, error=%d", symbol, GetLastError());
      return;
     }

   double pip = PipSize(symbol);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pip <= 0.0 || point <= 0.0)
     {
      PrintFormat("Invalid symbol point/pip metadata for %s.", symbol);
      return;
     }

   double spreads[];
   ArrayResize(spreads, 0);

   for(int i = 0; i < InpSamples; i++)
     {
      MqlTick tick;
      if(SymbolInfoTick(symbol, tick) && tick.ask > 0.0 && tick.bid > 0.0 && tick.ask >= tick.bid)
        {
         int n = ArraySize(spreads);
         ArrayResize(spreads, n + 1);
         spreads[n] = (tick.ask - tick.bid) / pip;
        }
      else
        {
         PrintFormat("Tick sample %d failed for %s, error=%d", i + 1, symbol, GetLastError());
        }

      if(i + 1 < InpSamples && InpSampleIntervalMs > 0)
         Sleep(InpSampleIntervalMs);
     }

   int sampleCount = ArraySize(spreads);
   if(sampleCount <= 0)
     {
      PrintFormat("No valid spread samples for %s.", symbol);
      return;
     }

   double pipValue = PipValuePerLot(symbol, pip);
   if(pipValue <= 0.0)
     {
      PrintFormat("Could not derive pip value per lot for %s.", symbol);
      return;
     }

   double spreadAvg = Average(spreads);
   double spreadMedian = Median(spreads);
   double spreadMin = MinValue(spreads);
   double spreadMax = MaxValue(spreads);
   double commissionRoundTurnPips = InpCommissionPerLotRoundTurn / pipValue;
   double slippageRoundTurnPips = InpExpectedSlippagePipsRoundTurn;
   double roundTurnCostPips = spreadAvg + commissionRoundTurnPips + slippageRoundTurnPips;
   double oneSideCostPips = roundTurnCostPips / 2.0;
   string decision = DecisionLabel(oneSideCostPips);

   Print("FX Time-of-Day Phase 0 cost check");
   PrintFormat("symbol=%s account_currency=%s samples=%d pip_size=%.*f pip_value_per_lot=%.4f",
               symbol, AccountInfoString(ACCOUNT_CURRENCY), sampleCount,
               (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS), pip, pipValue);
   PrintFormat("spread_pips avg=%.3f median=%.3f min=%.3f max=%.3f",
               spreadAvg, spreadMedian, spreadMin, spreadMax);
   PrintFormat("commission_roundturn=%.2f account_ccy = %.3f pips; slippage_roundturn=%.3f pips",
               InpCommissionPerLotRoundTurn, commissionRoundTurnPips, slippageRoundTurnPips);
   PrintFormat("roundturn_cost=%.3f pips; one_side_equivalent_cost=%.3f pips; decision=%s",
               roundTurnCostPips, oneSideCostPips, decision);
   PrintFormat("decision_note=%s", DecisionNote(oneSideCostPips));

   if(InpWriteCsv)
      WriteCsv(symbol,
               sampleCount,
               spreadAvg,
               spreadMedian,
               spreadMin,
               spreadMax,
               pipValue,
               commissionRoundTurnPips,
               slippageRoundTurnPips,
               roundTurnCostPips,
               oneSideCostPips,
               decision);
  }
