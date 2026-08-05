//+------------------------------------------------------------------+
//|                                              Ph_Divergence.mqh  |
//| Future2EA — RSI regular + hidden divergence (PRD v1.5)           |
//+------------------------------------------------------------------+
#ifndef PHASE_DIVERGENCE_MQH
#define PHASE_DIVERGENCE_MQH

#include "Phase_DivTypes.mqh"
#include "Phase_DivDraw.mqh"

// Dead zone: regular pivots between 35 and 65 rejected.
// Bullish: 1st pivot RSI < 45; 2nd anywhere OK (bear mirror)
// Bearish: 1st pivot RSI > 60; 2nd anywhere OK
// HD pivots: RSI MUST be andar 35-65 (upar 65 / neeche 35 pe HD nahi)
bool Ph_IsPivotInDeadZone(const double rsi,const double deadLow,const double deadHigh)
  {
   return(rsi >= deadLow && rsi <= deadHigh);
  }

// Bearish pivots: RSI > 60, NO upper limit (80/100 kuch bhi OK)
bool Ph_IsValidBearPivotRsi(const double rsi,const double deadLow,const double deadHigh)
  {
   // hard rule: sirf floor — RSI > 60; upper cap bilkul nahi
   return(rsi > 60.0);
  }

// Bullish pivots: RSI < 45, NO lower limit (0 tak OK)
bool Ph_IsValidBullPivotRsi(const double rsi,const double deadLow,const double deadHigh)
  {
   return(rsi < 45.0);
  }

bool Ph_FindPivotHigh(const int idx,const double &data[],const int left,const int right)
  {
   double value = data[idx];
   for(int i = 1; i <= left; i++)
      if(data[idx + i] > value)
         return(false);
   for(int i = 1; i <= right; i++)
      if(data[idx - i] > value)
         return(false);
   return(true);
  }

bool Ph_FindPivotLow(const int idx,const double &data[],const int left,const int right)
  {
   double value = data[idx];
   for(int i = 1; i <= left; i++)
      if(data[idx + i] < value)
         return(false);
   for(int i = 1; i <= right; i++)
      if(data[idx - i] < value)
         return(false);
   return(true);
  }

void Ph_ResolveRsiSwing(const int centerIdx,const bool isHigh,
                         const double &rsiValues[],const datetime &times[],
                         double &rsiValue,datetime &rsiTime)
  {
   int total = ArraySize(rsiValues);
   if(total <= 0 || centerIdx < 0 || centerIdx >= total)
      return;

   int startIdx = MathMax(0,centerIdx - 3);
   int endIdx = MathMin(total - 1,centerIdx + 3);
   int bestIdx = centerIdx;

   for(int i = startIdx; i <= endIdx; i++)
     {
      if(isHigh)
        {
         if(rsiValues[i] > rsiValues[bestIdx])
            bestIdx = i;
        }
      else
        {
         if(rsiValues[i] < rsiValues[bestIdx])
            bestIdx = i;
        }
     }
   rsiValue = rsiValues[bestIdx];
   rsiTime = times[bestIdx];
  }

int Ph_BarGap(const string symbol,const ENUM_TIMEFRAMES tf,
               const SPh_Pivot &prev,const SPh_Pivot &curr)
  {
   int prevShift = iBarShift(symbol,tf,prev.time,false);
   int currShift = iBarShift(symbol,tf,curr.time,false);
   if(prevShift < 0 || currShift < 0)
      return(MathAbs(prev.index - curr.index));
   return(MathAbs(prevShift - currShift));
  }

double Ph_LineAtShift(const int s1,const double v1,const int s2,const double v2,const int s)
  {
   if(s1 == s2)
      return(v2);
   double ratio = (double)(s - s1) / (double)(s2 - s1);
   return(v1 + ((v2 - v1) * ratio));
  }

// Price path: div line ke beech CLOSE cross = INVALID
// Wick touch / line "ari" = OK; sirf candle CLOSE line ke paar = reject
// Bearish (highs): beech ki close > line → reject
// Bullish (lows):  beech ki close < line → reject
bool Ph_IsPricePathClean(const string symbol,const ENUM_TIMEFRAMES tf,
                          const SPh_Pivot &prev,const SPh_Pivot &curr,const bool isHigh)
  {
   int prevShift = iBarShift(symbol,tf,prev.time,false);
   int currShift = iBarShift(symbol,tf,curr.time,false);
   if(prevShift < 0 || currShift < 0)
      return(true);

   int startShift = MathMax(prevShift,currShift);
   int endShift = MathMin(prevShift,currShift);
   if(startShift - endShift <= 1)
      return(true);

   for(int shift = startShift - 1; shift > endShift; shift--)
     {
      double lineVal = Ph_LineAtShift(prevShift,prev.price,currShift,curr.price,shift);
      double closePx = iClose(symbol,tf,shift);
      if(isHigh)
        {
         if(closePx > lineVal)
            return(false);
        }
      else
        {
         if(closePx < lineVal)
            return(false);
        }
     }
   return(true);
  }

// RSI path: div line ke beech RSI cross = INVALID (count nahi)
bool Ph_IsRsiPathClean(const string symbol,const ENUM_TIMEFRAMES tf,const int rsiHandle,
                        const SPh_Pivot &prev,const SPh_Pivot &curr,const bool isHigh)
  {
   if(rsiHandle == INVALID_HANDLE)
      return(true);

   int prevShift = iBarShift(symbol,tf,prev.rsiTime,false);
   int currShift = iBarShift(symbol,tf,curr.rsiTime,false);
   if(prevShift < 0 || currShift < 0)
      return(true);

   int startShift = MathMax(prevShift,currShift);
   int endShift = MathMin(prevShift,currShift);
   if(startShift - endShift <= 1)
      return(true);

   for(int shift = startShift - 1; shift > endShift; shift--)
     {
      double lineVal = Ph_LineAtShift(prevShift,prev.rsi,currShift,curr.rsi,shift);
      double rsiBuf[];
      if(CopyBuffer(rsiHandle,0,shift,1,rsiBuf) != 1)
         return(false);
      if(isHigh)
        {
         if(rsiBuf[0] > lineVal)
            return(false);
        }
      else
        {
         if(rsiBuf[0] < lineVal)
            return(false);
        }
     }
   return(true);
  }

bool Ph_IsDivPathClean(const string symbol,const ENUM_TIMEFRAMES tf,const int rsiHandle,
                        const SPh_Pivot &prev,const SPh_Pivot &curr,const bool isHigh)
  {
   if(!Ph_IsPricePathClean(symbol,tf,prev,curr,isHigh))
      return(false);
   return(Ph_IsRsiPathClean(symbol,tf,rsiHandle,prev,curr,isHigh));
  }

// HD: chart + RSI dono pe strict cross (HIGH/LOW + RSI value)
bool Ph_IsHdDivPathClean(const string symbol,const ENUM_TIMEFRAMES tf,const int rsiHandle,
                          const SPh_Pivot &prev,const SPh_Pivot &curr,const bool isHigh)
  {
   int prevShift = iBarShift(symbol,tf,prev.time,false);
   int currShift = iBarShift(symbol,tf,curr.time,false);
   if(prevShift < 0 || currShift < 0)
      return(true);

   int startShift = MathMax(prevShift,currShift);
   int endShift = MathMin(prevShift,currShift);
   if(startShift - endShift <= 1)
      return(Ph_IsRsiPathClean(symbol,tf,rsiHandle,prev,curr,isHigh));

   for(int shift = startShift - 1; shift > endShift; shift--)
     {
      double lineVal = Ph_LineAtShift(prevShift,prev.price,currShift,curr.price,shift);
      if(isHigh)
        {
         if(iHigh(symbol,tf,shift) > lineVal)
            return(false);
        }
      else
        {
         if(iLow(symbol,tf,shift) < lineVal)
            return(false);
        }
     }

   return(Ph_IsRsiPathClean(symbol,tf,rsiHandle,prev,curr,isHigh));
  }

// Regular bearish: Price HH + RSI LH
// 1st pivot RSI > 60 lazmi | 2nd pivot RSI anywhere OK (sirf LH chahiye)
// HD RSI = pivot candle (rsiBar). ResolveRsiSwing HD pe HH/LL bigaad deta tha.
double Ph_PivotRsiForHd(const SPh_Pivot &p)
  {
   if(p.rsiBar > 0.0)
      return(p.rsiBar);
   return(p.rsi);
  }

// HD/regular: price pivot ke ±right bars ke andar local RSI high/low
// NEAREST-in-time extremum (best-value steal band — galat HH/LH)
bool Ph_FindNearbyRsiExtremum(const string symbol,const ENUM_TIMEFRAMES tf,
                               const int rsiHandle,const datetime pivotTime,
                               const bool wantHigh,const int left,const int right,
                               double &outRsi,datetime &outTime)
  {
   outRsi = 0.0;
   outTime = 0;
   if(rsiHandle == INVALID_HANDLE || left < 1 || right < 1 || pivotTime <= 0)
      return(false);

   int center = iBarShift(symbol,tf,pivotTime,false);
   if(center < 0)
      return(false);

   int search = right;
   bool found = false;
   int bestDist = 100000;
   double bestRsi = wantHigh ? -1.0 : 1.0e10;

   for(int sh = center + search; sh >= center - search; sh--)
     {
      if(sh < right)
         break;
      int barsNeeded = left + right + 1;
      if(sh - right < 0)
         continue;

      double rsi[];
      if(CopyBuffer(rsiHandle,0,sh - right,barsNeeded,rsi) != barsNeeded)
         continue;
      ArraySetAsSeries(rsi,true);

      int idx = right;
      bool ok = wantHigh ? Ph_FindPivotHigh(idx,rsi,left,right)
                         : Ph_FindPivotLow(idx,rsi,left,right);
      if(!ok)
         continue;

      double v = rsi[idx];
      int dist = MathAbs(sh - center);
      bool better = (!found || dist < bestDist ||
                     (dist == bestDist && (wantHigh ? (v > bestRsi) : (v < bestRsi))));
      if(better)
        {
         bestDist = dist;
         bestRsi = v;
         outRsi = v;
         outTime = iTime(symbol,tf,sh);
         found = true;
        }
     }
   return(found);
  }

// Back-compat helper: exact candle local extremum?
bool Ph_IsRsiBarLocalExtremum(const string symbol,const ENUM_TIMEFRAMES tf,
                               const int rsiHandle,const datetime pivotTime,
                               const bool wantHigh,const int left,const int right)
  {
   double v;
   datetime t;
   if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,pivotTime,wantHigh,left,right,v,t))
      return(false);
   return(t == pivotTime);
  }

// Hidden pattern (LH+HH) kabhi regular nahi — rsiBar use
bool Ph_IsHiddenBearPattern(const SPh_Pivot &prev,const SPh_Pivot &curr)
  {
   return(curr.price < prev.price &&
          Ph_PivotRsiForHd(curr) > Ph_PivotRsiForHd(prev));
  }

bool Ph_IsRegularBearPattern(const SPh_Pivot &prev,const SPh_Pivot &curr)
  {
   // rsiBar = pivot candle (Resolve ±3 short-gap pe LH/HH bigaadta)
   // equal high bhi OK (flat HH)
   return(curr.price >= prev.price &&
          Ph_PivotRsiForHd(curr) < Ph_PivotRsiForHd(prev));
  }

bool Ph_IsHiddenBullPattern(const SPh_Pivot &prev,const SPh_Pivot &curr)
  {
   return(curr.price > prev.price &&
          Ph_PivotRsiForHd(curr) < Ph_PivotRsiForHd(prev));
  }

bool Ph_IsRegularBullPattern(const SPh_Pivot &prev,const SPh_Pivot &curr)
  {
   return(curr.price <= prev.price &&
          Ph_PivotRsiForHd(curr) > Ph_PivotRsiForHd(prev));
  }

// HD market cross: 1st pivot level break (slanted-line path-clean NAHI — false reject)
// Bear: beech high > 1st high → reject | Bull: beech low < 1st low → reject
bool Ph_IsHdMarketPathClean(const string symbol,const ENUM_TIMEFRAMES tf,
                             const SPh_Pivot &prev,const SPh_Pivot &curr,
                             const bool isHigh)
  {
   int prevShift = iBarShift(symbol,tf,prev.time,false);
   int currShift = iBarShift(symbol,tf,curr.time,false);
   if(prevShift < 0 || currShift < 0)
      return(true);

   int startShift = MathMax(prevShift,currShift);
   int endShift = MathMin(prevShift,currShift);
   if(startShift - endShift <= 1)
      return(true);

   for(int shift = startShift - 1; shift > endShift; shift--)
     {
      if(isHigh)
        {
         if(iHigh(symbol,tf,shift) > prev.price)
            return(false);
        }
      else
        {
         if(iLow(symbol,tf,shift) < prev.price)
            return(false);
        }
     }
   return(true);
  }

bool Ph_IsRegularBearDiv(const SPh_Pivot &prev,const SPh_Pivot &curr,
                          const double deadLow,const double deadHigh)
  {
   // HD pattern (price LH + RSI HH) → regular se bahar
   if(Ph_IsHiddenBearPattern(prev,curr))
      return(false);
   if(!Ph_IsRegularBearPattern(prev,curr))
      return(false);
   if(!Ph_IsValidBearPivotRsi(Ph_PivotRsiForHd(prev),deadLow,deadHigh))
      return(false);
   return(true);
  }

// Regular bullish: Price LL/equal + RSI HL; 1st RSI < 45, 2nd anywhere
bool Ph_IsRegularBullDiv(const SPh_Pivot &prev,const SPh_Pivot &curr,
                          const double deadLow,const double deadHigh)
  {
   if(Ph_IsHiddenBullPattern(prev,curr))
      return(false);
   if(!Ph_IsRegularBullPattern(prev,curr))
      return(false);
   // sirf 1st pivot floor — 2nd kahin bhi (bear jaisa)
   if(!Ph_IsValidBullPivotRsi(Ph_PivotRsiForHd(prev),deadLow,deadHigh))
      return(false);
   return(true);
  }

// Hidden bearish: Price LH + RSI HH — RSI zone filter nahi (pattern enough)
bool Ph_IsHiddenBearDiv(const SPh_Pivot &prev,const SPh_Pivot &curr)
  {
   return(Ph_IsHiddenBearPattern(prev,curr));
  }

// Hidden bullish: Price HL + RSI LL — RSI zone filter nahi (pattern enough)
bool Ph_IsHiddenBullDiv(const SPh_Pivot &prev,const SPh_Pivot &curr)
  {
   return(Ph_IsHiddenBullPattern(prev,curr));
  }

// BOS level: structure swing BETWEEN the two div pivots
// Bearish → lowest low between the two high pivots
// Bullish → highest high between the two low pivots (beech wala bounce high)
//           — pivotA se pehle wala major high NAHI (user correction)
bool Ph_CalcBosLevel(const string symbol,const ENUM_TIMEFRAMES tf,
                      const SPh_Pivot &pivotA,const SPh_Pivot &pivotB,
                      const EPh_DivType type,double &bosLevel,datetime &bosTime)
  {
   int shiftA = iBarShift(symbol,tf,pivotA.time,false);
   int shiftB = iBarShift(symbol,tf,pivotB.time,false);
   if(shiftA < 0 || shiftB < 0)
      return(false);

   int from = MathMax(shiftA,shiftB); // older pivot (larger shift)
   int to = MathMin(shiftA,shiftB);   // newer pivot
   bosTime = pivotA.time;

   if(type == Ph_DIV_BEAR)
     {
      bosLevel = iLow(symbol,tf,shiftA);
      for(int s = from; s >= to; s--)
        {
         double lo = iLow(symbol,tf,s);
         if(lo < bosLevel)
           {
            bosLevel = lo;
            bosTime = iTime(symbol,tf,s);
           }
        }
      return(true);
     }

   if(type == Ph_DIV_BULL)
     {
      bosLevel = iHigh(symbol,tf,shiftA);
      for(int s = from; s >= to; s--)
        {
         double hi = iHigh(symbol,tf,s);
         if(hi > bosLevel)
           {
            bosLevel = hi;
            bosTime = iTime(symbol,tf,s);
           }
        }
      return(true);
     }

   return(false);
  }

// Saari valid bear divs collect (nearest pehle) — visual pe sab draw
// Regular: dono pivots pe nearest RSI TOP; 1st RSI>60; 2nd dead-zone bahar; path clean
int Ph_CollectBearDivergences(SPh_Pivot &highs[],const int currPos,
                               const string symbol,const ENUM_TIMEFRAMES tf,
                               const int minBars,const int maxBars,
                               const double deadLow,const double deadHigh,
                               const int rsiHandle,const int pivotLeft,const int pivotRight,
                               SPh_Divergence &outDivs[])
  {
   ArrayResize(outDivs,0);
   if(currPos <= 0)
      return(0);

   SPh_Pivot curr = highs[currPos];
   for(int i = currPos - 1; i >= 0; i--)
     {
      SPh_Pivot prev = highs[i];
      int gap = Ph_BarGap(symbol,tf,prev,curr);
      if(gap < minBars)
         continue;
      if(gap > maxBars)
         break;

      if(curr.price < prev.price)
         continue;

      double rsiA = 0.0,rsiB = 0.0;
      datetime tA = 0,tB = 0;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,prev.time,true,pivotLeft,pivotRight,rsiA,tA))
         continue;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,curr.time,true,pivotLeft,pivotRight,rsiB,tB))
         continue;
      // Regular bear: HH/equal price + RSI LH — RSI must be 2 tops
      if(rsiB >= rsiA)
         continue;
      if(!Ph_IsValidBearPivotRsi(rsiA,deadLow,deadHigh))
         continue;
      // 2nd mid-zone (35–65) pe regular band — HD territory / false LH
      if(Ph_IsPivotInDeadZone(rsiB,deadLow,deadHigh))
         continue;

      SPh_Pivot a = prev;
      SPh_Pivot b = curr;
      a.rsi = rsiA;
      a.rsiTime = tA;
      a.rsiBar = rsiA;
      b.rsi = rsiB;
      b.rsiTime = tB;
      b.rsiBar = rsiB;

      if(Ph_IsHiddenBearPattern(a,b))
         continue;
      if(!Ph_IsDivPathClean(symbol,tf,rsiHandle,a,b,true))
         continue;

      double bosLvl = 0.0;
      datetime bosT = a.time;
      if(!Ph_CalcBosLevel(symbol,tf,a,b,Ph_DIV_BEAR,bosLvl,bosT))
         continue;

      int n = ArraySize(outDivs);
      ArrayResize(outDivs,n + 1);
      outDivs[n].valid = true;
      outDivs[n].isHidden = false;
      outDivs[n].type = Ph_DIV_BEAR;
      outDivs[n].pivotA = a;
      outDivs[n].pivotB = b;
      outDivs[n].bosLevel = bosLvl;
      outDivs[n].bosTime = bosT;
      outDivs[n].detectTime = curr.time;
     }
   return(ArraySize(outDivs));
  }

int Ph_CollectBullDivergences(SPh_Pivot &lows[],const int currPos,
                               const string symbol,const ENUM_TIMEFRAMES tf,
                               const int minBars,const int maxBars,
                               const double deadLow,const double deadHigh,
                               const int rsiHandle,const int pivotLeft,const int pivotRight,
                               SPh_Divergence &outDivs[])
  {
   ArrayResize(outDivs,0);
   if(currPos <= 0)
      return(0);

   SPh_Pivot curr = lows[currPos];
   for(int i = currPos - 1; i >= 0; i--)
     {
      SPh_Pivot prev = lows[i];
      int gap = Ph_BarGap(symbol,tf,prev,curr);
      if(gap < minBars)
         continue;
      if(gap > maxBars)
         break;

      if(curr.price > prev.price)
         continue;

      double rsiA = 0.0,rsiB = 0.0;
      datetime tA = 0,tB = 0;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,prev.time,false,pivotLeft,pivotRight,rsiA,tA))
         continue;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,curr.time,false,pivotLeft,pivotRight,rsiB,tB))
         continue;
      // Regular bull: LL/equal price + RSI HL — RSI must be 2 bottoms
      if(rsiB <= rsiA)
         continue;
      if(!Ph_IsValidBullPivotRsi(rsiA,deadLow,deadHigh))
         continue;
      if(Ph_IsPivotInDeadZone(rsiB,deadLow,deadHigh))
         continue;

      SPh_Pivot a = prev;
      SPh_Pivot b = curr;
      a.rsi = rsiA;
      a.rsiTime = tA;
      a.rsiBar = rsiA;
      b.rsi = rsiB;
      b.rsiTime = tB;
      b.rsiBar = rsiB;

      if(Ph_IsHiddenBullPattern(a,b))
         continue;
      if(!Ph_IsDivPathClean(symbol,tf,rsiHandle,a,b,false))
         continue;

      double bosLvl = 0.0;
      datetime bosT = a.time;
      if(!Ph_CalcBosLevel(symbol,tf,a,b,Ph_DIV_BULL,bosLvl,bosT))
         continue;

      int n = ArraySize(outDivs);
      ArrayResize(outDivs,n + 1);
      outDivs[n].valid = true;
      outDivs[n].isHidden = false;
      outDivs[n].type = Ph_DIV_BULL;
      outDivs[n].pivotA = a;
      outDivs[n].pivotB = b;
      outDivs[n].bosLevel = bosLvl;
      outDivs[n].bosTime = bosT;
      outDivs[n].detectTime = curr.time;
     }
   return(ArraySize(outDivs));
  }

// Hidden bear — price LH + nearby RSI 2 tops (HH); sirf nearest valid pair
int Ph_CollectHiddenBearDivergences(SPh_Pivot &highs[],const int currPos,
                                     const string symbol,const ENUM_TIMEFRAMES tf,
                                     const int minBars,const int maxBars,
                                     const double deadLow,const double deadHigh,
                                     const int rsiHandle,const int pivotLeft,const int pivotRight,
                                     SPh_Divergence &outDivs[])
  {
   ArrayResize(outDivs,0);
   if(currPos <= 0)
      return(0);

   SPh_Pivot curr = highs[currPos];
   for(int i = currPos - 1; i >= 0; i--)
     {
      SPh_Pivot prev = highs[i];
      int gap = Ph_BarGap(symbol,tf,prev,curr);
      if(gap < minBars)
         continue;
      if(gap > maxBars)
         break;

      if(curr.price >= prev.price)
         continue;

      double rsiA = 0.0,rsiB = 0.0;
      datetime tA = 0,tB = 0;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,prev.time,true,pivotLeft,pivotRight,rsiA,tA))
         continue;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,curr.time,true,pivotLeft,pivotRight,rsiB,tB))
         continue;
      if(tA == tB)
         continue;
      if(rsiB <= rsiA + 0.5)
         continue;
      // HD sirf 35-65 ke andar — 65+ / 35- pe yellow nahi
      if(!Ph_IsPivotInDeadZone(rsiA,deadLow,deadHigh) ||
         !Ph_IsPivotInDeadZone(rsiB,deadLow,deadHigh))
         continue;

      if(!Ph_IsHdMarketPathClean(symbol,tf,prev,curr,true))
         continue;

      SPh_Pivot a = prev;
      SPh_Pivot b = curr;
      a.rsi = rsiA;
      a.rsiTime = tA;
      b.rsi = rsiB;
      b.rsiTime = tB;

      if(!Ph_IsHdDivPathClean(symbol,tf,rsiHandle,a,b,true))
         continue;

      ArrayResize(outDivs,1);
      outDivs[0].valid = true;
      outDivs[0].isHidden = true;
      outDivs[0].type = Ph_DIV_BEAR;
      outDivs[0].pivotA = a;
      outDivs[0].pivotB = b;
      outDivs[0].bosLevel = 0.0;
      outDivs[0].bosTime = 0;
      outDivs[0].detectTime = curr.time;
      return(1);
     }
   return(0);
  }

// Hidden bull — price HL + nearby RSI 2 bottoms (LL); sirf nearest valid pair
int Ph_CollectHiddenBullDivergences(SPh_Pivot &lows[],const int currPos,
                                     const string symbol,const ENUM_TIMEFRAMES tf,
                                     const int minBars,const int maxBars,
                                     const double deadLow,const double deadHigh,
                                     const int rsiHandle,const int pivotLeft,const int pivotRight,
                                     SPh_Divergence &outDivs[])
  {
   ArrayResize(outDivs,0);
   if(currPos <= 0)
      return(0);

   SPh_Pivot curr = lows[currPos];
   for(int i = currPos - 1; i >= 0; i--)
     {
      SPh_Pivot prev = lows[i];
      int gap = Ph_BarGap(symbol,tf,prev,curr);
      if(gap < minBars)
         continue;
      if(gap > maxBars)
         break;

      if(curr.price <= prev.price)
         continue;

      double rsiA = 0.0,rsiB = 0.0;
      datetime tA = 0,tB = 0;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,prev.time,false,pivotLeft,pivotRight,rsiA,tA))
         continue;
      if(!Ph_FindNearbyRsiExtremum(symbol,tf,rsiHandle,curr.time,false,pivotLeft,pivotRight,rsiB,tB))
         continue;
      if(tA == tB)
         continue;
      if(rsiB >= rsiA - 0.5)
         continue;
      // HD sirf 35-65 ke andar — 65+ / 35- pe sky-blue nahi
      if(!Ph_IsPivotInDeadZone(rsiA,deadLow,deadHigh) ||
         !Ph_IsPivotInDeadZone(rsiB,deadLow,deadHigh))
         continue;

      if(!Ph_IsHdMarketPathClean(symbol,tf,prev,curr,false))
         continue;

      SPh_Pivot a = prev;
      SPh_Pivot b = curr;
      a.rsi = rsiA;
      a.rsiTime = tA;
      b.rsi = rsiB;
      b.rsiTime = tB;

      if(!Ph_IsHdDivPathClean(symbol,tf,rsiHandle,a,b,false))
         continue;

      ArrayResize(outDivs,1);
      outDivs[0].valid = true;
      outDivs[0].isHidden = true;
      outDivs[0].type = Ph_DIV_BULL;
      outDivs[0].pivotA = a;
      outDivs[0].pivotB = b;
      outDivs[0].bosLevel = 0.0;
      outDivs[0].bosTime = 0;
      outDivs[0].detectTime = curr.time;
      return(1);
     }
   return(0);
  }

// Same 2nd pivot pe kai divs: bull = highest BOS, bear = lowest BOS
// (nearest chhota bounce primary NAHI)
int Ph_PickPrimaryDivIndex(const SPh_Divergence &divs[],const int n)
  {
   int best = -1;
   for(int i = 0; i < n; i++)
     {
      if(!divs[i].valid || divs[i].isHidden || divs[i].bosLevel <= 0.0)
         continue;
      if(divs[i].type == Ph_DIV_BEAR &&
         Ph_IsHiddenBearPattern(divs[i].pivotA,divs[i].pivotB))
         continue;
      if(divs[i].type == Ph_DIV_BULL &&
         Ph_IsHiddenBullPattern(divs[i].pivotA,divs[i].pivotB))
         continue;

      if(best < 0)
        {
         best = i;
         continue;
        }

      if(divs[i].type == Ph_DIV_BULL)
        {
         if(divs[i].bosLevel > divs[best].bosLevel)
            best = i;
        }
      else if(divs[i].type == Ph_DIV_BEAR)
        {
         if(divs[i].bosLevel < divs[best].bosLevel)
            best = i;
        }
     }
   return(best);
  }

// Green/red "seq" = linked div chain (Low1→Low2→Low3).
// Path-clean aksar Low1→Low3 reject karti hai, lekin chart pe chain dikhti hai.
// BOS us poori chain ke span pe hona chahiye — last chhote bounce pe nahi.
int Ph_FindBullChainStartIdx(SPh_Pivot &lows[],const int currPos,
                              const string symbol,const ENUM_TIMEFRAMES tf,
                              const int minBars,const int maxBars,
                              const double deadLow,const double deadHigh,
                              const int rsiHandle)
  {
   if(currPos <= 0)
      return(currPos);

   int start = currPos;

   // Oldest direct valid pair with curr
   for(int i = 0; i < currPos; i++)
     {
      int gap = Ph_BarGap(symbol,tf,lows[i],lows[currPos]);
      if(gap < minBars)
         continue;
      if(gap > maxBars)
         continue;
      if(!Ph_IsRegularBullDiv(lows[i],lows[currPos],deadLow,deadHigh))
         continue;
      if(!Ph_IsDivPathClean(symbol,tf,rsiHandle,lows[i],lows[currPos],false))
         continue;
      start = i;
      break;
     }

   // Nearest-link walk: Low3→Low2→Low1 jab direct Low1→Low3 path-clean fail ho
   int walk = currPos;
   for(int guard = 0; guard < 64 && walk > 0; guard++)
     {
      int link = -1;
      for(int i = walk - 1; i >= 0; i--)
        {
         int gap = Ph_BarGap(symbol,tf,lows[i],lows[walk]);
         if(gap < minBars)
            continue;
         if(gap > maxBars)
            break;
         if(!Ph_IsRegularBullDiv(lows[i],lows[walk],deadLow,deadHigh))
            continue;
         if(!Ph_IsDivPathClean(symbol,tf,rsiHandle,lows[i],lows[walk],false))
            continue;
         link = i;
         break;
        }
      if(link < 0)
         break;
      walk = link;
     }

   if(walk < start)
      start = walk;
   return(start);
  }

int Ph_FindBearChainStartIdx(SPh_Pivot &highs[],const int currPos,
                              const string symbol,const ENUM_TIMEFRAMES tf,
                              const int minBars,const int maxBars,
                              const double deadLow,const double deadHigh,
                              const int rsiHandle)
  {
   if(currPos <= 0)
      return(currPos);

   int start = currPos;

   for(int i = 0; i < currPos; i++)
     {
      int gap = Ph_BarGap(symbol,tf,highs[i],highs[currPos]);
      if(gap < minBars)
         continue;
      if(gap > maxBars)
         continue;
      if(!Ph_IsRegularBearDiv(highs[i],highs[currPos],deadLow,deadHigh))
         continue;
      if(!Ph_IsDivPathClean(symbol,tf,rsiHandle,highs[i],highs[currPos],true))
         continue;
      start = i;
      break;
     }

   int walk = currPos;
   for(int guard = 0; guard < 64 && walk > 0; guard++)
     {
      int link = -1;
      for(int i = walk - 1; i >= 0; i--)
        {
         int gap = Ph_BarGap(symbol,tf,highs[i],highs[walk]);
         if(gap < minBars)
            continue;
         if(gap > maxBars)
            break;
         if(!Ph_IsRegularBearDiv(highs[i],highs[walk],deadLow,deadHigh))
            continue;
         if(!Ph_IsDivPathClean(symbol,tf,rsiHandle,highs[i],highs[walk],true))
            continue;
         link = i;
         break;
        }
      if(link < 0)
         break;
      walk = link;
     }

   if(walk < start)
      start = walk;
   return(start);
  }

// Primary div pe chain-span BOS apply (poori green/red seq ka structure swing)
bool Ph_ApplyChainBos(SPh_Pivot &pivots[],const int currPos,
                       const string symbol,const ENUM_TIMEFRAMES tf,
                       const int minBars,const int maxBars,
                       const double deadLow,const double deadHigh,
                       const int rsiHandle,SPh_Divergence &div)
  {
   if(!div.valid || currPos <= 0)
      return(false);

   int chainStart = currPos;
   if(div.type == Ph_DIV_BULL)
      chainStart = Ph_FindBullChainStartIdx(pivots,currPos,symbol,tf,minBars,maxBars,
                                             deadLow,deadHigh,rsiHandle);
   else if(div.type == Ph_DIV_BEAR)
      chainStart = Ph_FindBearChainStartIdx(pivots,currPos,symbol,tf,minBars,maxBars,
                                             deadLow,deadHigh,rsiHandle);
   else
      return(false);

   if(chainStart < 0 || chainStart >= currPos)
      return(true);

   double bosLvl = 0.0;
   datetime bosT = pivots[chainStart].time;
   if(!Ph_CalcBosLevel(symbol,tf,pivots[chainStart],pivots[currPos],div.type,bosLvl,bosT))
      return(false);

   div.pivotA = pivots[chainStart];
   div.pivotB = pivots[currPos];
   div.bosLevel = bosLvl;
   div.bosTime = bosT;
   div.detectTime = pivots[currPos].time;
   return(true);
  }

bool Ph_FindBearDivergence(SPh_Pivot &highs[],const int currPos,
                            const string symbol,const ENUM_TIMEFRAMES tf,
                            const int minBars,const int maxBars,
                            const double deadLow,const double deadHigh,
                            const int rsiHandle,SPh_Divergence &outDiv)
  {
   SPh_Divergence all[];
   int n = Ph_CollectBearDivergences(highs,currPos,symbol,tf,minBars,maxBars,
                                      deadLow,deadHigh,rsiHandle,2,2,all);
   int primary = Ph_PickPrimaryDivIndex(all,n);
   if(primary < 0)
     {
      outDiv.valid = false;
      return(false);
     }
   outDiv = all[primary];
   Ph_ApplyChainBos(highs,currPos,symbol,tf,minBars,maxBars,
                     deadLow,deadHigh,rsiHandle,outDiv);
   return(true);
  }

bool Ph_FindBullDivergence(SPh_Pivot &lows[],const int currPos,
                            const string symbol,const ENUM_TIMEFRAMES tf,
                            const int minBars,const int maxBars,
                            const double deadLow,const double deadHigh,
                            const int rsiHandle,SPh_Divergence &outDiv)
  {
   SPh_Divergence all[];
   int n = Ph_CollectBullDivergences(lows,currPos,symbol,tf,minBars,maxBars,
                                      deadLow,deadHigh,rsiHandle,2,2,all);
   int primary = Ph_PickPrimaryDivIndex(all,n);
   if(primary < 0)
     {
      outDiv.valid = false;
      return(false);
     }
   outDiv = all[primary];
   Ph_ApplyChainBos(lows,currPos,symbol,tf,minBars,maxBars,
                     deadLow,deadHigh,rsiHandle,outDiv);
   return(true);
  }

void Ph_DrawDivergenceLines(const long chartId,const int rsiSubwindow,
                             const SPh_Divergence &div,
                             const color bearClr,const color bullClr,
                             const color hidBearClr,const color hidBullClr,
                             const int width,const bool show)
  {
   if(!show || !div.valid)
      return;

   // Hidden: yellow / sky blue — sirf isHidden (zone-filtered collect)
   // Regular: red/lime — LH+HH pattern pe force-yellow NAHI (65+ pe galat yellow hota tha)
   color clr;
   string tag;
   if(div.isHidden)
     {
      clr = (div.type == Ph_DIV_BEAR) ? hidBearClr : hidBullClr;
      tag = (div.type == Ph_DIV_BEAR) ? "HidBear" : "HidBull";
     }
   else
     {
      clr = (div.type == Ph_DIV_BEAR) ? bearClr : bullClr;
      tag = (div.type == Ph_DIV_BEAR) ? "BearDiv" : "BullDiv";
     }

   string base = Ph_BuildId(tag,div.pivotA.time,div.pivotB.time);

   Ph_DrawTrend(chartId,base + "_P",0,
                 div.pivotA.time,div.pivotA.price,
                 div.pivotB.time,div.pivotB.price,clr,width);

   if(rsiSubwindow >= 0)
      Ph_DrawTrend(chartId,base + "_R",rsiSubwindow,
                    div.pivotA.rsiTime,div.pivotA.rsi,
                    div.pivotB.rsiTime,div.pivotB.rsi,clr,width);
  }

#endif
//+------------------------------------------------------------------+
