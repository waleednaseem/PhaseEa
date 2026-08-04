//+------------------------------------------------------------------+
//|                                              Phase_Types.mqh     |
//+------------------------------------------------------------------+
#ifndef PHASE_TYPES_MQH
#define PHASE_TYPES_MQH

enum ENUM_PH_REGIME
  {
   PH_NEUTRAL = 0,
   PH_BULLISH = 1,
   PH_BEARISH = 2
  };

struct SPhConfig
  {
   double bullFloor;
   double bullHard;     // zone edge: support must be clearly BELOW this
   double bearCapLo;
   double bearCap;      // zone edge: resist must be clearly ABOVE this
   double tol;
   double invGap;       // min distance from 20/35/65/80 (never on edge)
   double rsiFloor;     // S&R must stay clearly ABOVE this (20)
   double rsiCeil;      // S&R must stay clearly BELOW this (80)
   int    confirmBars;
   int    holdBars;
   int    capFailCount;
   int    historyBars;
   int    swingStrength;
   int    invLookback;  // max bars to search U-turn on sell enter
  };

struct SPhWalk
  {
   ENUM_PH_REGIME state;
   int  belowHard;
   int  aboveCap;
   int  pendingHold;
   int  capFails;
   int  floorHolds;
   int  breakInv;        // consecutive bars beyond INV
   int  invHold;         // bars stayed beyond INV after arm
   int  barsInRegime;    // anti-flicker lock after enter
   int  regimeStartShift;// shift when regime began (INV only after this)
   bool invBreakPending; // crossed INV — must STAY (reject cancels)
   bool breakoutPending;
   bool taggedCap;
   bool taggedFloor;
   bool hadBreakout;
   // per-regime INV from U-turn/bounce
   double   invLevel;    // BUY=support, SELL=resist
   datetime invTime;
   bool     invOn;
   int      invSegIdx;   // index in SR list to extend (-1 none)
  };

#define PH_SR_MAX 256
struct SPhSRSeg
  {
   datetime t0;
   datetime t1;
   double   level0;
   double   level1;
   bool     isSupport;
  };

struct SPhSRList
  {
   SPhSRSeg seg[PH_SR_MAX];
   int      count;
  };

void PhSRListClear(SPhSRList &L) { L.count = 0; }

int PhSRListAdd(SPhSRList &L,const datetime t0,const datetime t1,
                const double lvl,const bool isSup)
  {
   if(L.count >= PH_SR_MAX || t0 == 0 || t1 == 0)
      return(-1);
   datetime a = t0, b = t1;
   if(b < a) { datetime x=a; a=b; b=x; }
   if(b <= a)
      b = a + PeriodSeconds(_Period);
   int i = L.count++;
   L.seg[i].t0 = a;
   L.seg[i].t1 = b;
   L.seg[i].level0 = lvl;
   L.seg[i].level1 = lvl;
   L.seg[i].isSupport = isSup;
   return(i);
  }

void PhSRListExtend(SPhSRList &L,const int idx,const datetime tEnd)
  {
   if(idx < 0 || idx >= L.count || tEnd == 0)
      return;
   if(tEnd > L.seg[idx].t1)
      L.seg[idx].t1 = tEnd;
   if(tEnd < L.seg[idx].t0)
      L.seg[idx].t0 = tEnd;
  }

void PhWalkReset(SPhWalk &w)
  {
   w.state           = PH_NEUTRAL;
   w.belowHard       = 0;
   w.aboveCap        = 0;
   w.pendingHold     = 0;
   w.capFails        = 0;
   w.floorHolds      = 0;
   w.breakInv        = 0;
   w.invHold         = 0;
   w.barsInRegime     = 0;
   w.regimeStartShift = 0;
   w.invBreakPending  = false;
   w.breakoutPending  = false;
   w.taggedCap        = false;
   w.taggedFloor      = false;
   w.hadBreakout      = false;
   w.invLevel         = 0.0;
   w.invTime          = 0;
   w.invOn            = false;
   w.invSegIdx        = -1;
  }

void PhWalkClearBreakout(SPhWalk &w)
  {
   w.aboveCap        = 0;
   w.pendingHold     = 0;
   w.breakoutPending = false;
  }

void PhWalkClearInvBreak(SPhWalk &w)
  {
   w.breakInv        = 0;
   w.invHold         = 0;
   w.invBreakPending = false;
  }

void PhWalkClearInv(SPhWalk &w)
  {
   w.invLevel  = 0.0;
   w.invTime   = 0;
   w.invOn     = false;
   w.invSegIdx = -1;
   PhWalkClearInvBreak(w);
  }

#endif
//+------------------------------------------------------------------+
