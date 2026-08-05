//+------------------------------------------------------------------+
//|                                                      Ph_BOS.mqh |
//| Future2EA — Break of Structure gate (PRD v1.4)                   |
//+------------------------------------------------------------------+
#ifndef PHASE_BOS_MQH
#define PHASE_BOS_MQH

#include "Phase_DivTypes.mqh"
#include "Phase_DivDraw.mqh"

// Session gap: open alag prev close se — BOS/seq pe decision mat lo
bool Ph_IsMarketGapBar(const string symbol,const ENUM_TIMEFRAMES tf,const int shift,
                        const int minGapPoints=10)
  {
   if(shift < 0)
      return(false);
   int bars = iBars(symbol,tf);
   if(shift + 1 >= bars)
      return(false);
   double prevClose = iClose(symbol,tf,shift + 1);
   double currOpen  = iOpen(symbol,tf,shift);
   double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.00001;
   double thr = (minGapPoints > 0) ? (double)minGapPoints * point : point * 5.0;
   return(MathAbs(currOpen - prevClose) >= thr);
  }

// Check if BOS is broken on bar at shift (series: 0=current)
bool Ph_IsBosBroken(const string symbol,const ENUM_TIMEFRAMES tf,const int shift,
                     const EPh_DivType divType,const double bosLevel,
                     const EPh_BosBreakMode mode)
  {
   if(divType == Ph_DIV_BEAR)
     {
      if(mode == Ph_BOS_WICK)
         return(iLow(symbol,tf,shift) < bosLevel);
      return(iClose(symbol,tf,shift) < bosLevel);
     }
   if(divType == Ph_DIV_BULL)
     {
      if(mode == Ph_BOS_WICK)
         return(iHigh(symbol,tf,shift) > bosLevel);
      return(iClose(symbol,tf,shift) > bosLevel);
     }
   return(false);
  }

// Scan bars after detectTime for first BOS break; returns break bar time or 0
datetime Ph_FindBosBreakTime(const string symbol,const ENUM_TIMEFRAMES tf,
                              const datetime afterTime,const EPh_DivType divType,
                              const double bosLevel,const EPh_BosBreakMode mode,
                              const int maxLook)
  {
   int startShift = iBarShift(symbol,tf,afterTime,false);
   if(startShift < 0)
      return(0);

   // afterTime bar itself: start from startShift-1 (newer bars have smaller shift)
   for(int shift = startShift - 1; shift >= 0 && (startShift - shift) <= maxLook; shift--)
     {
      if(Ph_IsBosBroken(symbol,tf,shift,divType,bosLevel,mode))
         return(iTime(symbol,tf,shift));
     }
   return(0);
  }

// Line end = break bar (agar hit) warna bosTime + maxCandles
datetime Ph_BosLineEndTime(const string symbol,const ENUM_TIMEFRAMES tf,
                            const SPh_Divergence &div,const EPh_BosBreakMode mode,
                            const int maxCandles)
  {
   datetime startT = (div.bosTime > 0) ? div.bosTime : div.pivotA.time;
   int sec = Ph_PeriodSeconds(tf);
   if(sec <= 0)
      sec = 60;

   datetime breakT = Ph_FindBosBreakTime(symbol,tf,div.detectTime,div.type,
                                          div.bosLevel,mode,maxCandles);
   if(breakT > 0)
      return(breakT);

   return(startT + (datetime)(sec * maxCandles));
  }

void Ph_DrawBos(const long chartId,const SPh_Divergence &div,
                 const ENUM_TIMEFRAMES tf,const int maxCandles,
                 const EPh_BosBreakMode mode)
  {
   if(!div.valid)
      return;
   datetime startT = (div.bosTime > 0) ? div.bosTime : div.pivotA.time;
   datetime endT = Ph_BosLineEndTime(_Symbol,tf,div,mode,maxCandles);
   string name = Ph_BuildId("BOS",startT,div.detectTime);
   Ph_DrawBosLine(chartId,name,startT,endT,div.bosLevel,tf,clrWhite);
  }

// Hit ke baad line ko break bar pe truncate
void Ph_TruncateBosLine(const long chartId,const SPh_Divergence &div,
                         const datetime breakTime)
  {
   if(!div.valid || breakTime <= 0)
      return;
   datetime startT = (div.bosTime > 0) ? div.bosTime : div.pivotA.time;
   string name = Ph_BuildId("BOS",startT,div.detectTime);
   if(ObjectFind(chartId,name) < 0)
      return;
   datetime t1 = (datetime)ObjectGetInteger(chartId,name,OBJPROP_TIME,0);
   datetime endT = breakTime;
   if(endT < t1)
      endT = t1;
   ObjectMove(chartId,name,1,endT,div.bosLevel);
  }

// Seq flip / BOS use: saari purani BOS lines yahin stop — agay next seq disturb na kare
void Ph_StopAllBosLinesAt(const long chartId,const datetime stopTime)
  {
   if(stopTime <= 0)
      return;

   string prefix = g_phDivPrefix + "BOS_";
   int total = ObjectsTotal(chartId,0,OBJ_TREND);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(chartId,i,0,OBJ_TREND);
      if(StringFind(name,prefix) != 0)
         continue;

      datetime t1 = (datetime)ObjectGetInteger(chartId,name,OBJPROP_TIME,0);
      datetime t2 = (datetime)ObjectGetInteger(chartId,name,OBJPROP_TIME,1);
      double level = ObjectGetDouble(chartId,name,OBJPROP_PRICE,0);
      if(t2 <= stopTime)
         continue;

      datetime endT = stopTime;
      if(endT < t1)
         endT = t1;
      ObjectMove(chartId,name,1,endT,level);
     }
  }

// Confirmed bull div → lowest low; bear → highest high (invalidate level)
double Ph_GetDivInvalidateLevel(const SPh_Divergence &div)
  {
   if(!div.valid)
      return(0.0);
   if(div.type == Ph_DIV_BULL)
      return(MathMin(div.pivotA.price,div.pivotB.price));
   if(div.type == Ph_DIV_BEAR)
      return(MathMax(div.pivotA.price,div.pivotB.price));
   return(0.0);
  }

datetime Ph_GetDivInvalidateTime(const SPh_Divergence &div)
  {
   if(!div.valid)
      return(0);
   if(div.type == Ph_DIV_BULL)
     {
      if(div.pivotB.price <= div.pivotA.price)
         return(div.pivotB.time);
      return(div.pivotA.time);
     }
   if(div.type == Ph_DIV_BEAR)
     {
      if(div.pivotB.price >= div.pivotA.price)
         return(div.pivotB.time);
      return(div.pivotA.time);
     }
   return(div.detectTime);
  }

// Pivot-to-pivot bar span (detect-time indices; fallback via times)
int Ph_DivBarSpan(const SPh_Divergence &div)
  {
   if(!div.valid)
      return(0);
   int a = div.pivotA.index;
   int b = div.pivotB.index;
   if(a >= 0 && b >= 0)
      return(MathAbs(a - b));
   if(div.pivotA.time <= 0 || div.pivotB.time <= 0)
      return(0);
   int sa = iBarShift(_Symbol,_Period,div.pivotA.time,false);
   int sb = iBarShift(_Symbol,_Period,div.pivotB.time,false);
   if(sa < 0 || sb < 0)
      return(0);
   return(MathAbs(sa - sb));
  }

// Bull seq: close/wick below div low. Bear seq: close/wick above div high.
bool Ph_IsDivInvalidated(const string symbol,const ENUM_TIMEFRAMES tf,const int shift,
                          const EPh_SeqState seq,const double invLevel,
                          const EPh_BosBreakMode mode)
  {
   if(invLevel <= 0.0)
      return(false);
   if(seq == Ph_SEQ_BULL_ACTIVE)
      return(Ph_IsBosBroken(symbol,tf,shift,Ph_DIV_BEAR,invLevel,mode));
   if(seq == Ph_SEQ_BEAR_ACTIVE)
      return(Ph_IsBosBroken(symbol,tf,shift,Ph_DIV_BULL,invLevel,mode));
   return(false);
  }

// INV level reject (same-bar): wick/touch + close wapas (tol = near-miss touch)
// Bear Div High → high touches level && close back at/below → SELL
// Bull Div Low  → low touches level  && close back at/above → BUY
bool Ph_IsInvLevelRejected(const string symbol,const ENUM_TIMEFRAMES tf,const int shift,
                            const EPh_DivType divType,const double invLevel)
  {
   if(invLevel <= 0.0 || shift < 0)
      return(false);
   double hi = iHigh(symbol,tf,shift);
   double lo = iLow(symbol,tf,shift);
   double cl = iClose(symbol,tf,shift);
   double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.00001;
   // 2-point tol: chart pe visual touch / broker tick miss
   const double tol = 2.0 * point;
   if(divType == Ph_DIV_BEAR)
      return(hi + tol >= invLevel && cl <= invLevel);
   if(divType == Ph_DIV_BULL)
      return(lo - tol <= invLevel && cl >= invLevel);
   return(false);
  }

// Close wapas reject side pe (2nd bar after pierce/break) — wick check nahi
bool Ph_IsInvCloseBack(const string symbol,const ENUM_TIMEFRAMES tf,const int shift,
                        const EPh_DivType divType,const double invLevel)
  {
   if(invLevel <= 0.0 || shift < 0)
      return(false);
   double cl = iClose(symbol,tf,shift);
   if(divType == Ph_DIV_BEAR)
      return(cl <= invLevel);
   if(divType == Ph_DIV_BULL)
      return(cl >= invLevel);
   return(false);
  }

void Ph_DrawInvalidateLine(const long chartId,const SPh_Divergence &div,
                            const ENUM_TIMEFRAMES tf,const int maxCandles)
  {
   if(!div.valid)
      return;
   double level = Ph_GetDivInvalidateLevel(div);
   datetime startT = Ph_GetDivInvalidateTime(div);
   if(level <= 0.0 || startT <= 0)
      return;

   int sec = Ph_PeriodSeconds(tf);
   if(sec <= 0)
      sec = 60;
   datetime endT = startT + (datetime)(sec * maxCandles);
   string name = Ph_BuildId("INV",startT,div.detectTime);
   Ph_DrawBosLine(chartId,name,startT,endT,level,tf,clrWhite);
   string labelName = name + "_Lbl";
   if(ObjectFind(chartId,labelName) >= 0)
      ObjectSetString(chartId,labelName,OBJPROP_TEXT,
                      (div.type == Ph_DIV_BULL) ? "Div Low (invalidate)" : "Div High (invalidate)");
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,STYLE_DOT);
  }

void Ph_TruncateInvalidateLine(const long chartId,const SPh_Divergence &div,
                                const datetime breakTime)
  {
   if(!div.valid || breakTime <= 0)
      return;
   datetime startT = Ph_GetDivInvalidateTime(div);
   double level = Ph_GetDivInvalidateLevel(div);
   string name = Ph_BuildId("INV",startT,div.detectTime);
   if(ObjectFind(chartId,name) < 0)
      return;
   ObjectMove(chartId,name,1,breakTime,level);
  }

#endif
//+------------------------------------------------------------------+
