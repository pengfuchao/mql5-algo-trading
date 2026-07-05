//+------------------------------------------------------------------+
//|                             Script_Weekend_Gap_Stats.mq5         |
//|                                                                  |
//|  Phase 0 scanner for Weekend Gap Fade research.                   |
//|  This is a standalone MQL5 Script, not an EA. It scans M15 bars   |
//|  for weekend gaps, exports per-gap rows to CSV under MQL5/Files,  |
//|  and prints bucket summaries to the Experts log.                  |
//+------------------------------------------------------------------+
#property copyright "Jimmy"
#property version   "1.00"
#property script_show_inputs

input string   InpSymbols         = "EURUSD;USDJPY;GBPUSD"; // Semicolon-separated symbols
input datetime InpStartDate       = D'2015.01.01 00:00';    // Inclusive scan start
input datetime InpEndDate         = D'2026.06.30 23:59';    // Inclusive scan end
input int      InpFillWindowHours = 48;                     // Fill-test window after week open
input int      InpATRPeriod       = 14;                     // D1 ATR period for gap_vs_ATRD1

struct GapRow
  {
   datetime          weekOpenTime;
   double            prevClose;
   double            weekOpen;
   double            gapPoints;
   double            gapPips;
   double            gapVsAtrD1;
   bool              filled24h;
   bool              filled48h;
   int               barsToFill;
   double            maePips;
  };

struct BucketStats
  {
   int               count;
   int               filled48;
   double            maeValues[];
   double            barsValues[];
   double            gapValues[];
  };

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

string SafeFilePart(const string symbol)
  {
   string out = symbol;
   StringReplace(out, ".", "_");
   StringReplace(out, "#", "_");
   StringReplace(out, "/", "_");
   StringReplace(out, "\\", "_");
   return out;
  }

string TimeCsv(const datetime value)
  {
   return TimeToString(value, TIME_DATE|TIME_MINUTES);
  }

string DateFilePart(const datetime value)
  {
   string out = TimeToString(value, TIME_DATE);
   StringReplace(out, ".", "");
   return out;
  }

void AddValue(double &values[], const double value)
  {
   int n = ArraySize(values);
   ArrayResize(values, n + 1);
   values[n] = value;
  }

double Median(double &values[])
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

int BucketIndex(const double absGapPips)
  {
   if(absGapPips < 5.0)  return 0;
   if(absGapPips < 15.0) return 1;
   if(absGapPips < 30.0) return 2;
   if(absGapPips < 50.0) return 3;
   return 4;
  }

string BucketName(const int index)
  {
   if(index == 0) return "<5";
   if(index == 1) return "5-15";
   if(index == 2) return "15-30";
   if(index == 3) return "30-50";
   return ">50";
  }

bool IsFriday(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.day_of_week == 5);
  }

bool CrossedPrevClose(const bool gapUp, const MqlRates &bar, const double prevClose)
  {
   if(gapUp)
      return (bar.low <= prevClose);
   return (bar.high >= prevClose);
  }

double AdverseMovePips(const bool gapUp, const MqlRates &bar, const double weekOpen, const double pip)
  {
   if(pip <= 0.0)
      return 0.0;
   if(gapUp)
      return MathMax(0.0, (bar.high - weekOpen) / pip);
   return MathMax(0.0, (weekOpen - bar.low) / pip);
  }

double AtrAtTime(const string symbol, const int atrHandle, const datetime when)
  {
   if(atrHandle == INVALID_HANDLE)
      return 0.0;

   int shift = iBarShift(symbol, PERIOD_D1, when, false);
   if(shift < 0)
      return 0.0;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) < 1)
      return 0.0;
   return atr[0];
  }

void WriteCsvHeader(const int handle)
  {
   FileWrite(handle,
             "symbol",
             "week_open_time",
             "prev_friday_close_time",
             "prev_close",
             "week_open",
             "gap_points",
             "gap_pips",
             "gap_vs_ATRD1",
             "filled_24h",
             "filled_48h",
             "bars_to_fill",
             "MAE_pips");
  }

void WriteCsvRow(const int handle,
                 const string symbol,
                 const datetime prevCloseTime,
                 const GapRow &row)
  {
   FileWrite(handle,
             symbol,
             TimeCsv(row.weekOpenTime),
             TimeCsv(prevCloseTime),
             DoubleToString(row.prevClose, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
             DoubleToString(row.weekOpen, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
             DoubleToString(row.gapPoints, 1),
             DoubleToString(row.gapPips, 2),
             DoubleToString(row.gapVsAtrD1, 4),
             (row.filled24h ? "1" : "0"),
             (row.filled48h ? "1" : "0"),
             row.barsToFill,
             DoubleToString(row.maePips, 2));
  }

void AddToBucket(BucketStats &bucket, const GapRow &row)
  {
   bucket.count++;
   if(row.filled48h)
      bucket.filled48++;
   AddValue(bucket.maeValues, row.maePips);
   AddValue(bucket.gapValues, MathAbs(row.gapPips));
   if(row.barsToFill >= 0)
      AddValue(bucket.barsValues, (double)row.barsToFill);
  }

void PrintBucketSummary(const string symbol, BucketStats &buckets[])
  {
   PrintFormat("Weekend Gap bucket summary for %s", symbol);
   Print("Bucket | Samples | Fill48% | MedianGapPips | MedianMAEPips | MedianBarsToFill");
   for(int i = 0; i < 5; i++)
     {
      double fillRate = (buckets[i].count > 0) ? 100.0 * (double)buckets[i].filled48 / (double)buckets[i].count : 0.0;
      double medianGap = Median(buckets[i].gapValues);
      double medianMae = Median(buckets[i].maeValues);
      double medianBars = Median(buckets[i].barsValues);
      PrintFormat("%s | %d | %.1f%% | %.2f | %.2f | %.1f",
                  BucketName(i),
                  buckets[i].count,
                  fillRate,
                  medianGap,
                  medianMae,
                  medianBars);
     }
  }

bool ScanSymbol(const string symbol)
  {
   string sym = Trim(symbol);
   if(sym == "")
      return false;

   if(!SymbolSelect(sym, true))
     {
      PrintFormat("SymbolSelect failed for %s, err=%d", sym, GetLastError());
      return false;
     }

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double pip = PipSize(sym);
   if(point <= 0.0 || pip <= 0.0)
     {
      PrintFormat("Invalid point/pip for %s point=%.10f pip=%.10f", sym, point, pip);
      return false;
     }

   int scanWindowHours = MathMax(48, InpFillWindowHours);
   datetime copyStart = InpStartDate - 86400 * 30;
   datetime copyEnd = InpEndDate + (datetime)(scanWindowHours * 3600 + 86400);

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(sym, PERIOD_M15, copyStart, copyEnd, rates);
   if(copied <= 0)
     {
      PrintFormat("CopyRates M15 failed for %s, copied=%d err=%d", sym, copied, GetLastError());
      return false;
     }

   int atrHandle = iATR(sym, PERIOD_D1, MathMax(1, InpATRPeriod));
   if(atrHandle == INVALID_HANDLE)
     {
      PrintFormat("iATR D1 failed for %s, err=%d", sym, GetLastError());
      return false;
     }

   string fileName = "Weekend_Gap_Stats_" + SafeFilePart(sym) + "_" +
                     DateFilePart(InpStartDate) + "_" +
                     DateFilePart(InpEndDate) + ".csv";

   int file = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(file == INVALID_HANDLE)
     {
      PrintFormat("FileOpen failed for %s, err=%d", fileName, GetLastError());
      IndicatorRelease(atrHandle);
      return false;
     }
   WriteCsvHeader(file);

   BucketStats buckets[5];
   int samples = 0;
   int skippedShortGap = 0;
   int skippedDate = 0;

   for(int i = 0; i < copied - 1; i++)
     {
      if(!IsFriday(rates[i].time))
         continue;
      if(IsFriday(rates[i + 1].time))
         continue;

      datetime prevCloseTime = rates[i].time;
      datetime weekOpenTime = rates[i + 1].time;
      int gapSeconds = (int)(weekOpenTime - prevCloseTime);
      if(gapSeconds < 24 * 3600)
        {
         skippedShortGap++;
         continue;
        }
      if(weekOpenTime < InpStartDate || weekOpenTime > InpEndDate)
        {
         skippedDate++;
         continue;
        }

      double prevClose = rates[i].close;
      double weekOpen = rates[i + 1].open;
      double gapPrice = weekOpen - prevClose;
      bool gapUp = (gapPrice > 0.0);
      if(gapPrice == 0.0)
         gapUp = true;

      double atrD1 = AtrAtTime(sym, atrHandle, prevCloseTime);
      double absGapPrice = MathAbs(gapPrice);

      GapRow row;
      row.weekOpenTime = weekOpenTime;
      row.prevClose = prevClose;
      row.weekOpen = weekOpen;
      row.gapPoints = (point > 0.0) ? gapPrice / point : 0.0;
      row.gapPips = (pip > 0.0) ? gapPrice / pip : 0.0;
      row.gapVsAtrD1 = (atrD1 > 0.0) ? absGapPrice / atrD1 : 0.0;
      row.filled24h = false;
      row.filled48h = false;
      row.barsToFill = -1;
      row.maePips = 0.0;

      datetime end24 = weekOpenTime + 24 * 3600;
      datetime end48 = weekOpenTime + 48 * 3600;
      datetime endWindow = weekOpenTime + scanWindowHours * 3600;

      for(int j = i + 1; j < copied; j++)
        {
         if(rates[j].time > endWindow)
            break;

         row.maePips = MathMax(row.maePips, AdverseMovePips(gapUp, rates[j], weekOpen, pip));

         if(CrossedPrevClose(gapUp, rates[j], prevClose))
           {
            if(row.barsToFill < 0)
               row.barsToFill = j - (i + 1);
            if(rates[j].time <= end24)
               row.filled24h = true;
            if(rates[j].time <= end48)
               row.filled48h = true;
            break;
           }
        }

      WriteCsvRow(file, sym, prevCloseTime, row);
      AddToBucket(buckets[BucketIndex(MathAbs(row.gapPips))], row);
      samples++;
     }

   FileClose(file);
   IndicatorRelease(atrHandle);

   PrintFormat("%s Weekend Gap scan complete: samples=%d, skipped_short_gap=%d, skipped_date=%d, bars=%d, csv=%s",
               sym,
               samples,
               skippedShortGap,
               skippedDate,
               copied,
               fileName);
   PrintBucketSummary(sym, buckets);
   return true;
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   if(InpEndDate <= InpStartDate)
     {
      Print("InpEndDate must be later than InpStartDate.");
      return;
     }
   if(InpFillWindowHours < 1)
     {
      Print("InpFillWindowHours must be >= 1.");
      return;
     }

   string symbols[];
   int n = StringSplit(InpSymbols, ';', symbols);
   if(n <= 0)
     {
      Print("InpSymbols is empty.");
      return;
     }

   int ok = 0;
   for(int i = 0; i < n; i++)
     {
      if(ScanSymbol(symbols[i]))
         ok++;
     }

   PrintFormat("Weekend Gap Phase 0 scan finished: %d/%d symbols processed.", ok, n);
  }
//+------------------------------------------------------------------+
