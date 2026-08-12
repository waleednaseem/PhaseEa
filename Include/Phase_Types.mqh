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
   double rsiFloor;     // S&R clearly ABOVE (20)
   double rsiCeil;      // S&R clearly BELOW (80)
   double invNearSup;   // support never above this (25; below-35 zone)
   double invNearRes;   // resist never below this (70; above-65 zone)
   int    confirmBars;
   int    holdBars;
   int    capFailCount;
   int    historyBars;
   int    swingStrength;
   int    invLookback;  // max bars to search U-turn on enter
   int    invRefreshBars; // after S&R: re-scan this many bars, level can move
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
   // per-regime INV (unused — S&R OFF)
   double   invLevel;
   datetime invTime;
   bool     invOn;
   int      invSegIdx;
   // Zone stay 65/35: cross + retest bounce / hold-bounce / park
   bool     zBuyArmed;
   int      zBuyAge;
   bool     zBuyRetest;
   bool     zBuyPullback;
   bool     zSellArmed;
   int      zSellAge;
   bool     zSellRetest;
   bool     zSellPullback;
  };

#define PH_SR_MAX 256
#define PH_ZONE_STAY_BARS 5
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

void PhSRListSetLevel(SPhSRList &L,const int idx,const double lvl)
  {
   if(idx < 0 || idx >= L.count)
      return;
   L.seg[idx].level0 = lvl;
   L.seg[idx].level1 = lvl;
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
   w.zBuyArmed        = false;
   w.zBuyAge          = 0;
   w.zBuyRetest       = false;
   w.zBuyPullback     = false;
   w.zSellArmed       = false;
   w.zSellAge         = 0;
   w.zSellRetest      = false;
   w.zSellPullback    = false;
  }

void PhWalkClearZoneBuy(SPhWalk &w)
  {
   w.zBuyArmed    = false;
   w.zBuyAge      = 0;
   w.zBuyRetest   = false;
   w.zBuyPullback = false;
  }

void PhWalkClearZoneSell(SPhWalk &w)
  {
   w.zSellArmed    = false;
   w.zSellAge      = 0;
   w.zSellRetest   = false;
   w.zSellPullback = false;
  }

void PhWalkClearZoneStay(SPhWalk &w)
  {
   PhWalkClearZoneBuy(w);
   PhWalkClearZoneSell(w);
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

// --- 65/35 zone flip (S&R OFF): cross + retest bounce / hold bounce / park ---
bool PhStay_Above65(const SPhConfig &cfg,const double v)
  {
   return(v + 1e-9 >= cfg.bearCap + cfg.tol);
  }

bool PhStay_Below35(const SPhConfig &cfg,const double v)
  {
   return(v <= cfg.bullHard - cfg.tol + 1e-9);
  }

bool PhStay_In6065(const SPhConfig &cfg,const double v)
  {
   const double lo = cfg.bearCapLo - cfg.tol;
   const double hi = cfg.bearCap + cfg.tol;
   return(v + 1e-9 >= lo && v < hi);
  }

bool PhStay_In3540(const SPhConfig &cfg,const double v)
  {
   const double lo = cfg.bullHard - cfg.tol;
   const double hi = cfg.bullFloor + cfg.tol;
   return(v > lo && v <= hi + 1e-9);
  }

// Cross 65 up → arm.
// BUY flip ONLY if RSI reclaims 65 after 60-65 pullback (60-65 tick ≠ BUY).
bool PhStay_BuyConfirm(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder,
                       const bool canFlip)
  {
   const double lvl65 = cfg.bearCap + cfg.tol;
   const double lvl60 = cfg.bearCapLo - cfg.tol;

   if(vOlder < lvl65 && v + 1e-9 >= lvl65)
     {
      w.zBuyArmed    = true;
      w.zBuyAge      = 1;
      w.zBuyRetest   = false;
      w.zBuyPullback = false;
      return(false);
     }

   if(!w.zBuyArmed)
      return(false);

   if(v < lvl60)
     {
      PhWalkClearZoneBuy(w);
      return(false);
     }

   w.zBuyAge++;

   if(PhStay_In6065(cfg,v))
      w.zBuyRetest = true;
   // pullback = dipped while still above 65 (real u-turn), not any down tick
   if(PhStay_Above65(cfg,v) && v < vOlder)
      w.zBuyPullback = true;

   if(w.zBuyAge < 5)
      return(false);

   bool want = false;
   // Path A: visited 60-65, then bounce BACK above 65 (reclaim)
   if(w.zBuyRetest && PhStay_Above65(cfg,v) && v > vOlder)
      want = true;
   // Path B: never left 65, small u-turn then bounce up (still >65)
   else if(!w.zBuyRetest && w.zBuyPullback && PhStay_Above65(cfg,v) && v > vOlder)
      want = true;

   if(!want)
      return(false);
   if(!canFlip)
      return(false);

   PhWalkClearZoneBuy(w);
   return(true);
  }

// MUST cross 35 first; then 35-40 bounce-down OR u-turn below 35. No predict before cross.
bool PhStay_SellConfirm(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder,
                        const bool canFlip)
  {
   const double lvl35 = cfg.bullHard - cfg.tol;
   const double lvl40 = cfg.bullFloor + cfg.tol;

   // arm only on real 35 cross (not 40 touch / not already-in-zone)
   if(vOlder > lvl35 && v <= lvl35 + 1e-9)
     {
      w.zSellArmed    = true;
      w.zSellAge      = 1;
      w.zSellRetest   = false;
      w.zSellPullback = false;
      return(false);
     }

   if(!w.zSellArmed && PhStay_Below35(cfg,v))
     {
      w.zSellArmed    = true;
      w.zSellAge      = 1;
      w.zSellRetest   = false;
      w.zSellPullback = false;
      return(false);
     }

   if(!w.zSellArmed)
      return(false);

   if(v > lvl40)
     {
      PhWalkClearZoneSell(w);
      return(false);
     }

   w.zSellAge++;

   if(PhStay_In3540(cfg,v))
      w.zSellRetest = true;
   if(PhStay_Below35(cfg,v) && v > vOlder)
      w.zSellPullback = true;

   // Path A: 35-40 retest then bounce DOWN (zone crossed pehle, phir reject)
   if(w.zSellRetest && v < vOlder && v <= lvl40 + 1e-9)
     {
      if(!canFlip)
         return(false);
      PhWalkClearZoneSell(w);
      return(true);
     }
   // Path B: below 35, small u-turn then continue down
   if(w.zSellPullback && PhStay_Below35(cfg,v) && v < vOlder)
     {
      if(!canFlip)
         return(false);
      PhWalkClearZoneSell(w);
      return(true);
     }
   return(false);
  }

#endif
//+------------------------------------------------------------------+
