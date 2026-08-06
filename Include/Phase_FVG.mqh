//+------------------------------------------------------------------+
//|                                                 Phase_FVG.mqh    |
//| Fair Value Gap detect + dyn SL + brown reject + chart (from F2E) |
//| Cache: rebuild once / incremental new-bar (no full O(n²) thrash) |
//| Full FVG/iFVG concept + styling → Phase_PRD.md § FVG / iFVG      |
//+------------------------------------------------------------------+
#ifndef PHASE_FVG_MQH
#define PHASE_FVG_MQH

#define PH_FVG_TAG "PH_Fvg"

struct SPhFvg
  {
   bool     valid;
   bool     isBull;
   bool     filled;
   double   gapTop;
   double   gapBottom;
   datetime detectTime;
   int      c3Shift;
  };

struct SPhFvgCached
  {
   SPhFvg fvg;
   int    through;
   int    lastOuter;
  };

//--- module cache (shared by draw + trade reject / SL) -----------------
SPhFvgCached g_phFvgCache[];
int            g_phFvgCacheN        = 0;
datetime       g_phFvgCacheBar0     = 0;
string         g_phFvgCacheSym      = "";
ENUM_TIMEFRAMES g_phFvgCacheTf      = PERIOD_CURRENT;
int            g_phFvgCacheLookback = -1;
int            g_phFvgCacheMinGap   = -1;
string         g_phFvgDrawn[];
int            g_phFvgDrawnN        = 0;

// C1=shift+2, C2=shift+1, C3=shift — wick gap
bool PhFvg_DetectAtShift(const string symbol,const ENUM_TIMEFRAMES tf,const int shift,
                         const double minGapPrice,SPhFvg &out)
  {
   out.valid = false;
   out.filled = false;
   if(shift < 2)
      return(false);

   double h1 = iHigh(symbol,tf,shift + 2);
   double l1 = iLow(symbol,tf,shift + 2);
   double h2 = iHigh(symbol,tf,shift + 1);
   double l2 = iLow(symbol,tf,shift + 1);
   double o2 = iOpen(symbol,tf,shift + 1);
   double c2 = iClose(symbol,tf,shift + 1);
   double h3 = iHigh(symbol,tf,shift);
   double l3 = iLow(symbol,tf,shift);
   datetime t3 = iTime(symbol,tf,shift);
   if(t3 <= 0)
      return(false);

   if(c2 > o2)
     {
      double top = 0.0;
      if(h1 < l3)
         top = l3;
      else if(h1 < l2)
         top = l2;
      else
         return(false);
      double gap = top - h1;
      if(gap < minGapPrice)
         return(false);
      out.valid = true;
      out.isBull = true;
      out.gapTop = top;
      out.gapBottom = h1;
      out.detectTime = t3;
      out.c3Shift = shift;
      return(true);
     }

   if(c2 < o2)
     {
      double bot = 0.0;
      if(l1 > h3)
         bot = h3;
      else if(l1 > h2)
         bot = h2;
      else
         return(false);
      double gap = l1 - bot;
      if(gap < minGapPrice)
         return(false);
      out.valid = true;
      out.isBull = false;
      out.gapTop = l1;
      out.gapBottom = bot;
      out.detectTime = t3;
      out.c3Shift = shift;
      return(true);
     }

   return(false);
  }

int PhFvg_OuterSide(const double price,const SPhFvg &fvg)
  {
   if(price < fvg.gapBottom)
      return(-1);
   if(price > fvg.gapTop)
      return(1);
   return(0);
  }

void PhFvg_ApplyThroughBar(SPhFvgCached &ex,const double o,const double c)
  {
   int openOuter = PhFvg_OuterSide(o,ex.fvg);
   int closeOuter = PhFvg_OuterSide(c,ex.fvg);

   if(openOuter != 0 && closeOuter != 0 && openOuter != closeOuter)
      ex.through++;
   else if(closeOuter != 0 && ex.lastOuter != 0 && ex.lastOuter != closeOuter)
      ex.through++;
   else if(closeOuter != 0 && openOuter == 0 && ex.lastOuter != closeOuter)
      ex.through++;

   if(closeOuter != 0)
      ex.lastOuter = closeOuter;
   else if(openOuter != 0)
      ex.lastOuter = openOuter;
  }

int PhFvg_ThroughCrossCountRange(const string symbol,const ENUM_TIMEFRAMES tf,
                                 const SPhFvg &fvg,const int fromShift,const int toShiftInclusive,
                                 int &lastOuterOut)
  {
   int count = 0;
   int lastOuter = 0;
   lastOuterOut = 0;
   if(fromShift < toShiftInclusive)
      return(0);

   for(int s = fromShift; s >= toShiftInclusive; s--)
     {
      double o = iOpen(symbol,tf,s);
      double c = iClose(symbol,tf,s);
      int openOuter = PhFvg_OuterSide(o,fvg);
      int closeOuter = PhFvg_OuterSide(c,fvg);

      if(openOuter != 0 && closeOuter != 0 && openOuter != closeOuter)
         count++;
      else if(closeOuter != 0 && lastOuter != 0 && lastOuter != closeOuter)
         count++;
      else if(closeOuter != 0 && openOuter == 0 && lastOuter != closeOuter)
         count++;

      if(closeOuter != 0)
         lastOuter = closeOuter;
      else if(openOuter != 0)
         lastOuter = openOuter;
     }
   lastOuterOut = lastOuter;
   return(count);
  }

int PhFvg_ThroughCrossCount(const string symbol,const ENUM_TIMEFRAMES tf,const SPhFvg &fvg)
  {
   if(fvg.c3Shift < 1)
      return(0);
   int lo = 0;
   return(PhFvg_ThroughCrossCountRange(symbol,tf,fvg,fvg.c3Shift - 1,0,lo));
  }

void PhFvg_CacheClear()
  {
   ArrayResize(g_phFvgCache,0);
   g_phFvgCacheN = 0;
   g_phFvgCacheBar0 = 0;
   g_phFvgCacheSym = "";
   g_phFvgCacheTf = PERIOD_CURRENT;
   g_phFvgCacheLookback = -1;
   g_phFvgCacheMinGap = -1;
  }

void PhFvg_CacheRebuild(const string symbol,const ENUM_TIMEFRAMES tf,
                        const int lookbackBars,const int minGapPoints)
  {
   ArrayResize(g_phFvgCache,0);
   g_phFvgCacheN = 0;

   int hi = MathMax(2,lookbackBars);
   int totalBars = iBars(symbol,tf);
   if(totalBars <= 2)
     {
      g_phFvgCacheSym = symbol;
      g_phFvgCacheTf = tf;
      g_phFvgCacheLookback = lookbackBars;
      g_phFvgCacheMinGap = minGapPoints;
      g_phFvgCacheBar0 = iTime(symbol,tf,0);
      return;
     }
   hi = MathMin(hi,totalBars - 1);

   double minGap = (double)minGapPoints * SymbolInfoDouble(symbol,SYMBOL_POINT);

   for(int shift = 2; shift <= hi; shift++)
     {
      SPhFvg fvg;
      if(!PhFvg_DetectAtShift(symbol,tf,shift,minGap,fvg))
         continue;
      int lastOuter = 0;
      int through = 0;
      if(fvg.c3Shift >= 1)
         through = PhFvg_ThroughCrossCountRange(symbol,tf,fvg,fvg.c3Shift - 1,0,lastOuter);
      if(through >= 2)
         continue;
      fvg.filled = (through >= 1);

      ArrayResize(g_phFvgCache,g_phFvgCacheN + 1);
      g_phFvgCache[g_phFvgCacheN].fvg = fvg;
      g_phFvgCache[g_phFvgCacheN].through = through;
      g_phFvgCache[g_phFvgCacheN].lastOuter = lastOuter;
      g_phFvgCacheN++;
     }

   g_phFvgCacheSym = symbol;
   g_phFvgCacheTf = tf;
   g_phFvgCacheLookback = lookbackBars;
   g_phFvgCacheMinGap = minGapPoints;
   g_phFvgCacheBar0 = iTime(symbol,tf,0);
  }

void PhFvg_CacheAdvanceOne(const string symbol,const ENUM_TIMEFRAMES tf,
                           const int lookbackBars,const double minGap)
  {
   // Age shifts; drop out-of-window
   for(int i = g_phFvgCacheN - 1; i >= 0; i--)
     {
      g_phFvgCache[i].fvg.c3Shift++;
      if(g_phFvgCache[i].fvg.c3Shift > lookbackBars)
        {
         for(int j = i; j < g_phFvgCacheN - 1; j++)
            g_phFvgCache[j] = g_phFvgCache[j + 1];
         g_phFvgCacheN--;
         ArrayResize(g_phFvgCache,g_phFvgCacheN);
        }
     }

   // New closed bar is shift 1 — update through counts
   double o1 = iOpen(symbol,tf,1);
   double c1 = iClose(symbol,tf,1);
   for(int i = g_phFvgCacheN - 1; i >= 0; i--)
     {
      if(g_phFvgCache[i].fvg.c3Shift < 1)
         continue;
      PhFvg_ApplyThroughBar(g_phFvgCache[i],o1,c1);
      g_phFvgCache[i].fvg.filled = (g_phFvgCache[i].through >= 1);
      if(g_phFvgCache[i].through >= 2)
        {
         for(int j = i; j < g_phFvgCacheN - 1; j++)
            g_phFvgCache[j] = g_phFvgCache[j + 1];
         g_phFvgCacheN--;
         ArrayResize(g_phFvgCache,g_phFvgCacheN);
        }
     }

   // Newly confirmed C3 at shift 2
   SPhFvg neu;
   if(PhFvg_DetectAtShift(symbol,tf,2,minGap,neu))
     {
      bool dup = false;
      for(int i = 0; i < g_phFvgCacheN; i++)
        {
         if(g_phFvgCache[i].fvg.detectTime == neu.detectTime &&
            g_phFvgCache[i].fvg.isBull == neu.isBull)
           {
            dup = true;
            break;
           }
        }
      if(!dup)
        {
         ArrayResize(g_phFvgCache,g_phFvgCacheN + 1);
         g_phFvgCache[g_phFvgCacheN].fvg = neu;
         g_phFvgCache[g_phFvgCacheN].through = 0;
         g_phFvgCache[g_phFvgCacheN].lastOuter = 0;
         g_phFvgCache[g_phFvgCacheN].fvg.filled = false;
         g_phFvgCacheN++;
        }
     }
  }

void PhFvg_CacheEnsure(const string symbol,const ENUM_TIMEFRAMES tf,
                       const int lookbackBars,const int minGapPoints)
  {
   datetime t0 = iTime(symbol,tf,0);
   bool paramsChanged =
      (g_phFvgCacheSym != symbol || g_phFvgCacheTf != tf ||
       g_phFvgCacheLookback != lookbackBars || g_phFvgCacheMinGap != minGapPoints);

   if(paramsChanged || g_phFvgCacheN < 0 || g_phFvgCacheBar0 == 0)
     {
      PhFvg_CacheRebuild(symbol,tf,lookbackBars,minGapPoints);
      return;
     }

   if(t0 == 0 || t0 == g_phFvgCacheBar0)
      return;

   int sh = iBarShift(symbol,tf,g_phFvgCacheBar0,false);
   if(sh < 0 || sh > 2)
     {
      PhFvg_CacheRebuild(symbol,tf,lookbackBars,minGapPoints);
      return;
     }

   double minGap = (double)minGapPoints * SymbolInfoDouble(symbol,SYMBOL_POINT);
   for(int step = 0; step < sh; step++)
      PhFvg_CacheAdvanceOne(symbol,tf,lookbackBars,minGap);

   g_phFvgCacheBar0 = t0;
   g_phFvgCacheSym = symbol;
   g_phFvgCacheTf = tf;
   g_phFvgCacheLookback = lookbackBars;
   g_phFvgCacheMinGap = minGapPoints;
  }

int PhFvg_CollectActive(const string symbol,const ENUM_TIMEFRAMES tf,
                        const int lookbackBars,const int minGapPoints,
                        SPhFvg &out[])
  {
   PhFvg_CacheEnsure(symbol,tf,lookbackBars,minGapPoints);
   ArrayResize(out,0);
   int count = 0;
   for(int i = 0; i < g_phFvgCacheN; i++)
     {
      if(g_phFvgCache[i].through >= 2)
         continue;
      ArrayResize(out,count + 1);
      out[count] = g_phFvgCache[i].fvg;
      out[count].filled = (g_phFvgCache[i].through >= 1);
      count++;
     }
   return(count);
  }

// SL-side FVGs nearest→far: sell=above entry, buy=below entry
int PhFvg_GetSlSideTrio(const string symbol,const ENUM_TIMEFRAMES tf,
                        const bool isSell,const double entry,
                        const int lookbackBars,const int minGapPoints,
                        const int maxPoints,
                        SPhFvg &fvg1,SPhFvg &fvg2,SPhFvg &fvg3)
  {
   fvg1.valid = false;
   fvg2.valid = false;
   fvg3.valid = false;
   if(entry <= 0.0 || maxPoints <= 0)
      return(0);

   double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point <= 0.0)
      return(0);
   double maxDist = (double)maxPoints * point;
   double winLo = entry - maxDist;
   double winHi = entry + maxDist;

   SPhFvg all[];
   int n = PhFvg_CollectActive(symbol,tf,lookbackBars,minGapPoints,all);
   if(n <= 0)
      return(0);

   double keys[];
   double slLevels[];
   SPhFvg cands[];
   int cand = 0;

   for(int i = 0; i < n; i++)
     {
      double top = all[i].gapTop;
      double bot = all[i].gapBottom;
      if(top <= bot)
         continue;

      double key = 0.0;
      double sl  = 0.0;

      if(isSell)
        {
         if(bot >= winHi || top <= entry)
            continue;
         key = (bot > entry) ? (bot - entry) : 0.0;
         sl  = top;
         if(sl <= entry)
            continue;
        }
      else
        {
         if(top <= winLo || bot >= entry)
            continue;
         key = (entry > top) ? (entry - top) : 0.0;
         sl  = bot;
         if(sl >= entry)
            continue;
        }

      bool dup = false;
      for(int d = 0; d < cand; d++)
        {
         if(MathAbs(keys[d] - key) <= point && MathAbs(slLevels[d] - sl) <= point)
           {
            dup = true;
            break;
           }
        }
      if(dup)
         continue;

      ArrayResize(keys,cand + 1);
      ArrayResize(slLevels,cand + 1);
      ArrayResize(cands,cand + 1);
      keys[cand]     = key;
      slLevels[cand] = sl;
      cands[cand]    = all[i];
      cand++;
     }

   // partial selection sort — only need top 3
   int need = MathMin(3,cand);
   for(int a = 0; a < need; a++)
     {
      int best = a;
      for(int b = a + 1; b < cand; b++)
        {
         if(keys[b] < keys[best] || (keys[b] == keys[best] &&
            ((isSell && slLevels[b] < slLevels[best]) ||
             (!isSell && slLevels[b] > slLevels[best]))))
            best = b;
        }
      if(best != a)
        {
         double tk = keys[a]; keys[a] = keys[best]; keys[best] = tk;
         double ts = slLevels[a]; slLevels[a] = slLevels[best]; slLevels[best] = ts;
         SPhFvg tfvg = cands[a]; cands[a] = cands[best]; cands[best] = tfvg;
        }
     }

   if(cand >= 1) { fvg1 = cands[0]; fvg1.valid = true; }
   if(cand >= 2) { fvg2 = cands[1]; fvg2.valid = true; }
   if(cand >= 3) { fvg3 = cands[2]; fvg3.valid = true; }
   return(cand);
  }

// Prefer 2nd FVG (≥min pts); else 3rd ≥min; else false → caller min-pips fallback
// minPoints must be PhTrade_PipsToPoints(max(800,slPips)) — never allow tighter SL
bool PhFvg_FindSecondSl(const string symbol,const ENUM_TIMEFRAMES tf,
                        const bool isSell,const double entry,
                        const int lookbackBars,const int minGapPoints,
                        const int maxPoints,double &slOut,
                        const int minPoints=0)
  {
   slOut = 0.0;
   if(entry <= 0.0 || maxPoints <= 0)
      return(false);

   double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   if(point <= 0.0)
      return(false);

   // Legacy skipNear was 600 *points* — must never beat the 800-pip floor (minPoints)
   const int needMin = (minPoints > 0) ? minPoints : 0;
   const int distNeed = MathMax(600,needMin);

   SPhFvg f1,f2,f3;
   int cand = PhFvg_GetSlSideTrio(symbol,tf,isSell,entry,lookbackBars,
                                  minGapPoints,maxPoints,f1,f2,f3);

   double f2sl = (f2.valid) ? (isSell ? f2.gapTop : f2.gapBottom) : 0.0;
   double f3sl = (f3.valid) ? (isSell ? f3.gapTop : f3.gapBottom) : 0.0;

   if(f2.valid && f2sl > 0.0 &&
      ((isSell && f2sl > entry) || (!isSell && f2sl < entry)))
     {
      int d2 = (int)MathRound(MathAbs(f2sl - entry) / point);
      if(d2 >= distNeed)
        {
         slOut = NormalizeDouble(f2sl,digits);
         Print("Phase FVG-SL pick=2nd/",cand," dist=",d2,"pts sl=",DoubleToString(slOut,digits));
         return(true);
        }
      Print("Phase FVG-SL 2nd skip dist=",d2,"pts need>=",distNeed," → try 3rd");
     }

   if(f3.valid && f3sl > 0.0 &&
      ((isSell && f3sl > entry) || (!isSell && f3sl < entry)))
     {
      int d3 = (int)MathRound(MathAbs(f3sl - entry) / point);
      if(d3 >= needMin && d3 >= distNeed)
        {
         slOut = NormalizeDouble(f3sl,digits);
         Print("Phase FVG-SL pick=3rd/",cand," dist=",d3,"pts sl=",DoubleToString(slOut,digits));
         return(true);
        }
      Print("Phase FVG-SL 3rd skip dist=",d3,"pts need>=",distNeed);
     }

   return(false);
  }

//--- brown soft reject helpers (trade; draw optional) -----------------------
bool PhFvg_BarTouchesZone(const double hi,const double lo,const SPhFvg &fvg)
  {
   return(lo <= fvg.gapTop && hi >= fvg.gapBottom);
  }

void PhFvg_CrossCountsBeforeShift(const string symbol,const ENUM_TIMEFRAMES tf,
                                  const SPhFvg &fvg,const int shift,
                                  int &upCrosses,int &downCrosses,
                                  int &fullUpCrosses,int &fullDownCrosses)
  {
   upCrosses = 0;
   downCrosses = 0;
   fullUpCrosses = 0;
   fullDownCrosses = 0;
   int c3 = iBarShift(symbol,tf,fvg.detectTime,false);
   if(c3 < 1)
      c3 = fvg.c3Shift;
   if(c3 < 1)
      return;

   int minS = shift + 1;
   for(int s = c3 - 1; s >= minS; s--)
     {
      double o = iOpen(symbol,tf,s);
      double c = iClose(symbol,tf,s);
      if(c > fvg.gapTop && o <= fvg.gapTop)
        {
         upCrosses++;
         if(o < fvg.gapBottom)
            fullUpCrosses++;
        }
      else if(c < fvg.gapBottom && o >= fvg.gapBottom)
        {
         downCrosses++;
         if(o > fvg.gapTop)
            fullDownCrosses++;
        }
     }
  }

// Soft/full cross before `shift` → no fresh brown reject arm/fire
bool PhFvg_WasCrossedBeforeShift(const string symbol,const ENUM_TIMEFRAMES tf,
                                 const SPhFvg &fvg,const int shift)
  {
   int upCrosses = 0, downCrosses = 0, fullUpCrosses = 0, fullDownCrosses = 0;
   PhFvg_CrossCountsBeforeShift(symbol,tf,fvg,shift,upCrosses,downCrosses,
                                fullUpCrosses,fullDownCrosses);
   return(upCrosses >= 1 || downCrosses >= 1);
  }

// sideFilter: 0=any | 1=lower (prev close above) | 2=upper (prev close below)
bool PhFvg_FindBrownTouchAtShift(const string symbol,const ENUM_TIMEFRAMES tf,
                                 const int shift,const int lookbackBars,
                                 const int minGapPoints,const int sideFilter,
                                 SPhFvg &outFvg,datetime &outBarTime)
  {
   outFvg.valid = false;
   outBarTime = 0;
   if(shift < 0)
      return(false);
   datetime barTime = iTime(symbol,tf,shift);
   if(barTime <= 0)
      return(false);
   outBarTime = barTime;

   double hi = iHigh(symbol,tf,shift);
   double lo = iLow(symbol,tf,shift);
   double prevClose = iClose(symbol,tf,shift + 1);
   if(prevClose <= 0.0 && iTime(symbol,tf,shift + 1) <= 0)
      return(false);

   SPhFvg all[];
   int n = PhFvg_CollectActive(symbol,tf,lookbackBars,minGapPoints,all);
   bool have = false;
   for(int i = 0; i < n; i++)
     {
      if(all[i].filled)
         continue;
      if(PhFvg_WasCrossedBeforeShift(symbol,tf,all[i],shift))
         continue;
      if(all[i].detectTime > 0 && all[i].detectTime > barTime)
         continue;
      if(!PhFvg_BarTouchesZone(hi,lo,all[i]))
         continue;

      if(sideFilter == 1 && !(prevClose > all[i].gapTop))
         continue;
      if(sideFilter == 2 && !(prevClose < all[i].gapBottom))
         continue;

      if(!have)
        {
         outFvg = all[i];
         have = true;
        }
      else if(sideFilter == 1)
        {
         if(all[i].gapTop > outFvg.gapTop)
            outFvg = all[i];
        }
      else if(sideFilter == 2)
        {
         if(all[i].gapBottom < outFvg.gapBottom)
            outFvg = all[i];
        }
      else
        {
         outFvg = all[i];
         break;
        }
     }
   return(have);
  }

//--- chart draw (main price pane) — brown=open, grey=iFVG -----------------
int PhFvg_ClampWidthBars(const int widthBars,const int minBars,const int maxBars)
  {
   return(MathMax(minBars,MathMin(maxBars,widthBars)));
  }

void PhFvg_DeleteTracked(const long chartId=0)
  {
   for(int i = 0; i < g_phFvgDrawnN; i++)
      ObjectDelete(chartId,g_phFvgDrawn[i]);
   ArrayResize(g_phFvgDrawn,0);
   g_phFvgDrawnN = 0;
  }

void PhFvg_DeleteObjects(const long chartId=0)
  {
   PhFvg_DeleteTracked(chartId);
   // orphan sweep (deinit / hide) — once, not every bar
   int total = ObjectsTotal(chartId,-1,-1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(chartId,i,-1,-1);
      if(StringFind(name,PH_FVG_TAG) == 0)
         ObjectDelete(chartId,name);
     }
  }

void PhFvg_TrackDrawn(const string name)
  {
   ArrayResize(g_phFvgDrawn,g_phFvgDrawnN + 1);
   g_phFvgDrawn[g_phFvgDrawnN++] = name;
  }

void PhFvg_DrawFilledRect(const long chartId,const string name,
                          const datetime t1,const double top,
                          const datetime t2,const double bottom,
                          const color borderClr,const color fillClr)
  {
   if(ObjectFind(chartId,name) < 0)
      ObjectCreate(chartId,name,OBJ_RECTANGLE,0,t1,top,t2,bottom);
   else
     {
      ObjectMove(chartId,name,0,t1,top);
      ObjectMove(chartId,name,1,t2,bottom);
     }
   ObjectSetInteger(chartId,name,OBJPROP_COLOR,borderClr);
   ObjectSetInteger(chartId,name,OBJPROP_BGCOLOR,fillClr);
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(chartId,name,OBJPROP_FILL,true);
   ObjectSetInteger(chartId,name,OBJPROP_BACK,true);
   ObjectSetInteger(chartId,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(chartId,name,OBJPROP_HIDDEN,true);
  }

string PhFvg_ObjName(const SPhFvg &fvg)
  {
   return(PH_FVG_TAG + (fvg.isBull ? "B_" : "R_") + IntegerToString((long)fvg.detectTime));
  }

void PhFvg_DrawOne(const long chartId,const SPhFvg &fvg,const ENUM_TIMEFRAMES tf,
                   const int widthBars,const int minWidthBars,const int maxWidthBars,
                   const color fillClr,const color borderClr,
                   const color fillFilledClr,const color borderFilledClr)
  {
   if(!fvg.valid || fvg.detectTime <= 0)
      return;
   int w = PhFvg_ClampWidthBars(widthBars,minWidthBars,maxWidthBars);
   int sec = PeriodSeconds(tf);
   if(sec <= 0)
      sec = 60;
   datetime t1 = fvg.detectTime;
   datetime t2 = t1 + (datetime)(w * sec);
   string name = PhFvg_ObjName(fvg);
   color fill = fvg.filled ? fillFilledClr : fillClr;
   color border = fvg.filled ? borderFilledClr : borderClr;
   PhFvg_DrawFilledRect(chartId,name,t1,fvg.gapTop,t2,fvg.gapBottom,border,fill);
   PhFvg_TrackDrawn(name);
  }

void PhFvg_SortByRecency(SPhFvg &arr[],const int count)
  {
   for(int i = 0; i < count - 1; i++)
     {
      int best = i;
      for(int j = i + 1; j < count; j++)
        {
         if(arr[j].c3Shift < arr[best].c3Shift)
            best = j;
        }
      if(best != i)
        {
         SPhFvg tmp = arr[i];
         arr[i] = arr[best];
         arr[best] = tmp;
        }
     }
  }

// Incremental draw: cache ensure + in-place update; no ObjectsTotal each bar
void PhFvg_Refresh(const long chartId,const string symbol,const ENUM_TIMEFRAMES tf,
                   const int lookbackBars,const bool show,
                   const int widthBars,const int minWidthBars,const int maxWidthBars,
                   const int minGapPoints,const int maxShow,
                   const color fillClr,const color borderClr,
                   const color fillFilledClr,const color borderFilledClr)
  {
   if(!show)
     {
      if(g_phFvgDrawnN > 0)
         PhFvg_DeleteObjects(chartId);
      return; // trade path uses CollectActive/cache separately — no draw work
     }

   // Keep previous names to drop orphans after redraw
   string prev[];
   int prevN = g_phFvgDrawnN;
   ArrayResize(prev,prevN);
   for(int i = 0; i < prevN; i++)
      prev[i] = g_phFvgDrawn[i];
   ArrayResize(g_phFvgDrawn,0);
   g_phFvgDrawnN = 0;

   SPhFvg all[];
   int n = PhFvg_CollectActive(symbol,tf,lookbackBars,minGapPoints,all);
   if(n <= 0)
     {
      for(int i = 0; i < prevN; i++)
         ObjectDelete(chartId,prev[i]);
      return;
     }

   PhFvg_SortByRecency(all,n);
   int drawCount = MathMin(n,MathMax(1,maxShow));
   for(int i = 0; i < drawCount; i++)
      PhFvg_DrawOne(chartId,all[i],tf,widthBars,minWidthBars,maxWidthBars,
                    fillClr,borderClr,fillFilledClr,borderFilledClr);

   // delete names no longer wanted
   for(int i = 0; i < prevN; i++)
     {
      bool keep = false;
      for(int j = 0; j < g_phFvgDrawnN; j++)
        {
         if(prev[i] == g_phFvgDrawn[j])
           {
            keep = true;
            break;
           }
        }
      if(!keep)
         ObjectDelete(chartId,prev[i]);
     }
  }

#endif
//+------------------------------------------------------------------+
