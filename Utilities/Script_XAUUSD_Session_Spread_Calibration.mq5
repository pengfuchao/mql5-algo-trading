//+------------------------------------------------------------------+
//|              Script_XAUUSD_Session_Spread_Calibration.mq5        |
//|                                                                  |
//|  Gold Intraday Seasonality preset calibration helper.             |
//|                                                                  |
//|  Purpose: derive a defensible InpMaxSpreadPts for the            |
//|  Strategy_Time_Window XAUUSD research presets (MAIN + CTRL-1/2/3) |
//|  without waiting five trading days for live spread samples.       |
//|                                                                  |
//|  Method: MqlRates.spread carries the broker-recorded spread per   |
//|  bar in POINTS. Scanning M1 history and grouping by server hour   |
//|  yields the full intraday spread distribution in one run, which   |
//|  calibrates every research window at once.                        |
//|                                                                  |
//|  UNITS: this script reports POINTS, matching                      |
//|  Strategy_Time_Window.mq5 CurrentSpreadPoints() = (ask-bid)/Point.|
//|  Do NOT feed pip-based figures from                               |
//|  Script_FX_TimeOfDay_Cost_Check.mq5 into InpMaxSpreadPts: that    |
//|  script reports pips, and pip == point only when digits is 2 or 4.|
//|                                                                  |
//|  LIMITATION: historical bar spread is the broker's recorded value |
//|  and demo servers can understate real dealing spread. Cross-check |
//|  the recommendation with two or three live Asia-session samples    |
//|  before freezing a preset. This script does not trade.            |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"
#property script_show_inputs

input string           InpSymbol          = "XAUUSD";        // Symbol to inspect (blank = chart symbol)
input datetime         InpStartDate       = D'2025.01.01';   // Scan start (server time)
input datetime         InpEndDate         = D'2026.06.30';   // Scan end (server time)
input ENUM_TIMEFRAMES  InpTimeframe       = PERIOD_M1;       // Sampling timeframe
input int              InpWindowStartHour = 3;               // Target window start hour (server); MAIN = 3
input int              InpWindowEndHour   = 10;              // Target window end hour (server, exclusive); MAIN = 10
input double           InpSafetyMult      = 1.5;             // Recommendation = median * this multiplier
input bool             InpWriteCsv        = true;            // Write evidence CSV to MQL5/Files

//--- MQL5 allows only the first array dimension to be dynamic, so per-hour
//--- buckets are held as an array of structs rather than double[24][].
struct HourBucket
  {
   double            values[];
  };

//+------------------------------------------------------------------+
string Trim(const string value)
  {
   string result = value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
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

//--- Percentile on an already ascending-sorted array, nearest-rank.
double PercentileSorted(const double &sorted[], const double fraction)
  {
   int n = ArraySize(sorted);
   if(n <= 0)
      return 0.0;

   int index = (int)MathCeil(fraction * n) - 1;
   index = (int)MathMax(0, MathMin(n - 1, index));
   return sorted[index];
  }

double MedianSorted(const double &sorted[])
  {
   int n = ArraySize(sorted);
   if(n <= 0)
      return 0.0;
   if((n % 2) == 1)
      return sorted[n / 2];
   return 0.5 * (sorted[n / 2 - 1] + sorted[n / 2]);
  }

//--- Window membership with cross-midnight support (end hour exclusive).
bool HourInWindow(const int hour, const int startHour, const int endHour)
  {
   if(startHour == endHour)
      return true;                       // full-day window (CTRL-3 style)
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   string symbol = Trim(InpSymbol);
   if(symbol == "")
      symbol = _Symbol;

   if(InpStartDate >= InpEndDate)
     {
      Print("Invalid inputs: InpStartDate must be earlier than InpEndDate.");
      return;
     }
   if(InpWindowStartHour < 0 || InpWindowStartHour > 23 ||
      InpWindowEndHour < 0 || InpWindowEndHour > 23)
     {
      Print("Invalid inputs: window hours must be within 0..23.");
      return;
     }
   if(InpSafetyMult <= 0.0)
     {
      Print("Invalid inputs: InpSafetyMult must be > 0.");
      return;
     }
   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("SymbolSelect failed for %s, error=%d", symbol, GetLastError());
      return;
     }

   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
     {
      PrintFormat("Invalid symbol point metadata for %s.", symbol);
      return;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(symbol, InpTimeframe, InpStartDate, InpEndDate, rates);
   if(copied <= 0)
     {
      PrintFormat("CopyRates failed for %s, error=%d. Load history in the terminal first.",
                  symbol, GetLastError());
      return;
     }

   //--- Bucket spreads by server hour, and collect the target window separately.
   HourBucket byHour[24];
   int        hourCount[24];
   for(int h = 0; h < 24; h++)
     {
      ArrayResize(byHour[h].values, 0);
      hourCount[h] = 0;
     }

   double windowSpreads[];
   ArrayResize(windowSpreads, 0);

   int skippedZero = 0;
   for(int i = 0; i < copied; i++)
     {
      double spreadPts = (double)rates[i].spread;
      if(spreadPts <= 0.0)
        {
         //--- Zero spread rows are missing metadata, not free trading; exclude them
         //--- so the distribution is not biased downward.
         skippedZero++;
         continue;
        }

      MqlDateTime dt;
      TimeToStruct(rates[i].time, dt);
      int h = dt.hour;

      //--- Reserve blocks so a multi-hundred-thousand-bar M1 scan does not
      //--- reallocate on every append.
      int n = ArraySize(byHour[h].values);
      ArrayResize(byHour[h].values, n + 1, 65536);
      byHour[h].values[n] = spreadPts;
      hourCount[h]++;

      if(HourInWindow(h, InpWindowStartHour, InpWindowEndHour))
        {
         int m = ArraySize(windowSpreads);
         ArrayResize(windowSpreads, m + 1, 65536);
         windowSpreads[m] = spreadPts;
        }
     }

   int windowSamples = ArraySize(windowSpreads);
   if(windowSamples <= 0)
     {
      PrintFormat("No usable spread samples in window %02d:00-%02d:00 for %s (bars scanned=%d, zero-spread rows=%d).",
                  InpWindowStartHour, InpWindowEndHour, symbol, copied, skippedZero);
      return;
     }

   Print("XAUUSD session spread calibration (units: POINTS)");
   PrintFormat("symbol=%s digits=%d point=%.*f timeframe=%s",
               symbol, digits, digits, point, EnumToString(InpTimeframe));
   PrintFormat("range_requested=%s .. %s bars_scanned=%d zero_spread_rows_excluded=%d",
               TimeToString(InpStartDate, TIME_DATE),
               TimeToString(InpEndDate, TIME_DATE),
               copied, skippedZero);

   //--- History depth check. CopyRates silently returns only what the terminal
   //--- holds, so a requested range is not evidence the data exists. Compare the
   //--- actual first bar against the request before trusting any long backtest.
   datetime actualFirst = rates[0].time;
   datetime actualLast  = rates[copied - 1].time;
   double   spanDays    = (double)(actualLast - actualFirst) / 86400.0;
   double   expectedBars = spanDays * (5.0 / 7.0) * 1440.0;
   double   coveragePct  = (expectedBars > 0.0) ? (100.0 * copied / expectedBars) : 0.0;

   PrintFormat("range_actual=%s .. %s span=%.0f days coverage=%.0f%% of a continuous 5-day-week M1 series",
               TimeToString(actualFirst, TIME_DATE|TIME_MINUTES),
               TimeToString(actualLast, TIME_DATE|TIME_MINUTES),
               spanDays, coveragePct);
   if(actualFirst > InpStartDate + 86400)
      PrintFormat("WARNING: history starts %.0f days after the requested start. The terminal lacks the earlier data; any backtest over the requested range will silently cover less than intended.",
                  (double)(actualFirst - InpStartDate) / 86400.0);
   if(coveragePct < 80.0)
      PrintFormat("WARNING: coverage %.0f%% indicates gaps inside the returned span, not just a late start. Download full M1 history before drawing period-split conclusions.",
                  coveragePct);
   if(digits != 2)
      PrintFormat("NOTE: digits=%d (not the common XAUUSD 2). Point size is %.*f; confirm the preset unit before use.",
                  digits, digits, point);

   //--- Hourly breakdown: calibrates MAIN and every CTRL window in one pass.
   Print("hour | samples |    avg |  median |     p90 |     p95 |     max");
   for(int h = 0; h < 24; h++)
     {
      if(hourCount[h] <= 0)
        {
         PrintFormat("%02d   |       0 |      - |       - |       - |       - |       -", h);
         continue;
        }

      double sorted[];
      ArrayCopy(sorted, byHour[h].values);
      ArraySort(sorted);

      PrintFormat("%02d   | %7d | %6.1f | %7.1f | %7.1f | %7.1f | %7.1f",
                  h,
                  hourCount[h],
                  Average(byHour[h].values),
                  MedianSorted(sorted),
                  PercentileSorted(sorted, 0.90),
                  PercentileSorted(sorted, 0.95),
                  PercentileSorted(sorted, 1.00));
     }

   //--- Target window aggregate and recommendation.
   double windowSorted[];
   ArrayCopy(windowSorted, windowSpreads);
   ArraySort(windowSorted);

   double windowAvg    = Average(windowSpreads);
   double windowMedian = MedianSorted(windowSorted);
   double windowP90    = PercentileSorted(windowSorted, 0.90);
   double windowP95    = PercentileSorted(windowSorted, 0.95);
   double windowMax    = PercentileSorted(windowSorted, 1.00);
   double recommended  = windowMedian * InpSafetyMult;

   PrintFormat("window %02d:00-%02d:00 server: samples=%d avg=%.1f median=%.1f p90=%.1f p95=%.1f max=%.1f (points)",
               InpWindowStartHour, InpWindowEndHour, windowSamples,
               windowAvg, windowMedian, windowP90, windowP95, windowMax);
   PrintFormat("price-equivalent: median=%.*f p95=%.*f (quote currency per oz)",
               digits, windowMedian * point, digits, windowP95 * point);
   PrintFormat("RECOMMENDED InpMaxSpreadPts = %.1f  (median %.1f x %.2f)",
               recommended, windowMedian, InpSafetyMult);

   if(recommended < windowP90)
      PrintFormat("WARNING: recommendation %.1f sits below the window p90 %.1f, so more than 10%% of bars would gate entries. Consider raising the multiplier or reporting the skip rate.",
                  recommended, windowP90);
   Print("Reminder: cross-check against two or three live Asia-session samples before freezing the preset; demo history can understate real spread.");

   if(!InpWriteCsv)
      return;

   string fileName = StringFormat("XAUUSD_Session_Spread_Calibration_%s_%s.csv",
                                  SafeFilePart(symbol),
                                  TimeFilePart(TimeCurrent()));
   int handle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("CSV write failed: %s, error=%d", fileName, GetLastError());
      return;
     }

   FileWrite(handle, "symbol", symbol);
   FileWrite(handle, "digits", digits);
   FileWrite(handle, "point", DoubleToString(point, 8));
   FileWrite(handle, "timeframe", EnumToString(InpTimeframe));
   FileWrite(handle, "range_requested_start", TimeToString(InpStartDate, TIME_DATE));
   FileWrite(handle, "range_requested_end", TimeToString(InpEndDate, TIME_DATE));
   FileWrite(handle, "range_actual_start", TimeToString(actualFirst, TIME_DATE|TIME_MINUTES));
   FileWrite(handle, "range_actual_end", TimeToString(actualLast, TIME_DATE|TIME_MINUTES));
   FileWrite(handle, "actual_span_days", DoubleToString(spanDays, 1));
   FileWrite(handle, "coverage_pct_of_continuous_m1", DoubleToString(coveragePct, 1));
   FileWrite(handle, "bars_scanned", copied);
   FileWrite(handle, "zero_spread_rows_excluded", skippedZero);
   FileWrite(handle, "");
   FileWrite(handle, "hour", "samples", "avg_points", "median_points", "p90_points", "p95_points", "max_points");
   for(int h = 0; h < 24; h++)
     {
      if(hourCount[h] <= 0)
        {
         FileWrite(handle, h, 0, "", "", "", "", "");
         continue;
        }

      double sorted[];
      ArrayCopy(sorted, byHour[h].values);
      ArraySort(sorted);

      FileWrite(handle,
                h,
                hourCount[h],
                DoubleToString(Average(byHour[h].values), 2),
                DoubleToString(MedianSorted(sorted), 2),
                DoubleToString(PercentileSorted(sorted, 0.90), 2),
                DoubleToString(PercentileSorted(sorted, 0.95), 2),
                DoubleToString(PercentileSorted(sorted, 1.00), 2));
     }
   FileWrite(handle, "");
   FileWrite(handle, "window_start_hour", InpWindowStartHour);
   FileWrite(handle, "window_end_hour", InpWindowEndHour);
   FileWrite(handle, "window_samples", windowSamples);
   FileWrite(handle, "window_avg_points", DoubleToString(windowAvg, 2));
   FileWrite(handle, "window_median_points", DoubleToString(windowMedian, 2));
   FileWrite(handle, "window_p90_points", DoubleToString(windowP90, 2));
   FileWrite(handle, "window_p95_points", DoubleToString(windowP95, 2));
   FileWrite(handle, "window_max_points", DoubleToString(windowMax, 2));
   FileWrite(handle, "safety_multiplier", DoubleToString(InpSafetyMult, 2));
   FileWrite(handle, "recommended_max_spread_points", DoubleToString(recommended, 2));
   FileClose(handle);
   PrintFormat("CSV written to MQL5/Files/%s", fileName);
  }
//+------------------------------------------------------------------+
