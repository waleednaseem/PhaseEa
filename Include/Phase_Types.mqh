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
   // per-regime INV (dotted regime S&R)
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
   // Opposite-zone bounce (no 65/35 cross): 35-40 up → BUY, 60-65 down → SELL
   bool     zOppBuyArmed;
   bool     zOppSellArmed;
   int      loopStep;       // 0-1-2: 0=regular Div, 1=same-side, 2=latched until Div
   // Sharp S&R (PriceSR dotted) for loop step 1/2 — stay = park too long
   bool     loopSrArmed;
   bool     loopSrIsSup;
   double   loopSrLvl;
   int      loopSrPark;
   // Step-1 extreme: reject peak → break UP invalidates; bounce trough → break DOWN invalidates
   double   loopStep1Ext;
   bool     loopStep1Peak;  // true=reject (SELL path step1), false=bounce (BUY path step1)
   datetime loopStep1Time;
   bool     loopEvt0;       // stamp 0 this bar (regular Div only)
   bool     loopEvt1;
   bool     loopEvt2;
   datetime loopKill1Time;  // 1 invalidate → remove stamp, no 0
   bool     loop50Armed;    // tagged 50 after 012
   bool     loop50Ready;    // 012 complete — 50 switch allowed (idle-2 nahi)
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
   w.zOppBuyArmed     = false;
   w.zOppSellArmed    = false;
   w.loopStep         = 2;    // idle until regular Div (=0)
   w.loopSrArmed      = false;
   w.loopSrIsSup      = false;
   w.loopSrLvl        = 0.0;
   w.loopSrPark       = 0;
   w.loopStep1Ext     = 0.0;
   w.loopStep1Peak    = false;
   w.loopStep1Time    = 0;
   w.loopEvt0         = false;
   w.loopEvt1         = false;
   w.loopEvt2         = false;
   w.loopKill1Time    = 0;
   w.loop50Armed      = false;
   w.loop50Ready      = false;
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

void PhWalkClearLoopSr(SPhWalk &w)
  {
   w.loopSrArmed = false;
   w.loopSrIsSup = false;
   w.loopSrLvl   = 0.0;
   w.loopSrPark  = 0;
  }

void PhWalkClearLoopStep1(SPhWalk &w)
  {
   w.loopStep1Ext  = 0.0;
   w.loopStep1Peak = false;
   w.loopStep1Time = 0;
  }

void PhWalkClearZoneStay(SPhWalk &w)
  {
   PhWalkClearZoneBuy(w);
   PhWalkClearZoneSell(w);
   w.zOppBuyArmed  = false;
   w.zOppSellArmed = false;
   w.loop50Armed   = false;
   PhWalkClearLoopSr(w);
   PhWalkClearLoopStep1(w);
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

// --- 65/35 zone flip + PriceSR sharp: cross + retest bounce / hold bounce ---
#define PH_LOOP_SR_TOUCH 1.5
#define PH_LOOP_SR_STAY  3
#define PH_LOOP_OVERSHOOT 3.0
#define PH_LOOP_EDGE     1.0  // 59=60, 41=40 — loop 1/2 merge
#define PH_LOOP_50       50.0
#define PH_LOOP_50_BAND  2.5

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

// Uncertain market: allow slight overshoot above 65 for step-1 reject
bool PhStay_In6065Loose(const SPhConfig &cfg,const double v)
  {
   const double lo = cfg.bearCapLo - cfg.tol - PH_LOOP_EDGE; // 59
   const double hi = cfg.bearCap + cfg.tol + PH_LOOP_OVERSHOOT;
   return(v + 1e-9 >= lo && v <= hi + 1e-9);
  }

bool PhStay_In3540(const SPhConfig &cfg,const double v)
  {
   const double lo = cfg.bullHard - cfg.tol;
   const double hi = cfg.bullFloor + cfg.tol;
   return(v > lo && v <= hi + 1e-9);
  }

// Uncertain market: allow slight undershoot below 35 for step-1 bounce
bool PhStay_In3540Loose(const SPhConfig &cfg,const double v)
  {
   const double lo = cfg.bullHard - cfg.tol - PH_LOOP_OVERSHOOT;
   const double hi = cfg.bullFloor + cfg.tol + PH_LOOP_EDGE; // 41
   return(v + 1e-9 >= lo && v <= hi + 1e-9);
  }

// 0 = regular Div only (stamp). RSI 35-65 bahar se 0 nahi.
bool PhStay_LoopTryMark0(SPhWalk &w,const bool newRegularDiv)
  {
   if(!newRegularDiv)
      return(false);
   if(w.loopStep1Time > 0)
      w.loopKill1Time = w.loopStep1Time;
   w.loopStep = 0;
   w.loopEvt0 = true;
   w.loop50Ready = false;
   w.loop50Armed = false;
   PhWalkClearLoopSr(w);
   PhWalkClearLoopStep1(w);
   return(true);
  }

// Confirm step 1 + remember extreme (break of extreme → cancel 1)
void PhStay_LoopSet1(SPhWalk &w,const double v,const double vOlder,
                     const bool isPeakReject,const datetime barT)
  {
   w.loopStep      = 1;
   w.loopStep1Peak = isPeakReject;
   w.loopStep1Ext  = isPeakReject ? MathMax(v,vOlder) : MathMin(v,vOlder);
   w.loopStep1Time = barT;
   w.loopEvt1      = true;
  }

// While at 1: peak break UP / trough break DOWN → wapas wait (1 stamp hataye, 0 stamp nahi)
bool PhStay_LoopInvalidate1(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   if(w.loopStep != 1 || w.loopStep1Ext <= 0.0)
      return(false);
   const double tol = MathMax(0.5,cfg.tol);
   bool broken = false;
   if(w.loopStep1Peak)
      broken = (v > w.loopStep1Ext + tol);
   else
      broken = (v < w.loopStep1Ext - tol);
   if(!broken)
      return(false);
   w.loopKill1Time = w.loopStep1Time;
   w.loopStep = 0;
   w.zOppBuyArmed  = false;
   w.zOppSellArmed = false;
   PhWalkClearLoopSr(w);
   PhWalkClearLoopStep1(w);
   return(true);
  }

// SELL→BUY: 35-40 bounce UP (loose OK). Deep dump below cancels.
bool PhStay_BounceBuyFrom3540(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   const double lvl40 = cfg.bullFloor + cfg.tol + PH_LOOP_EDGE; // 41
   const double deep  = cfg.bullHard - cfg.tol - PH_LOOP_OVERSHOOT;

   if(v <= deep + 1e-9)
     {
      w.zOppBuyArmed = false;
      return(false);
     }

   if(PhStay_In3540Loose(cfg,v))
     {
      if(!w.zOppBuyArmed)
        {
         if(vOlder > lvl40)
            w.zOppBuyArmed = true;
         return(false);
        }
      if(v > vOlder)
        {
         w.zOppBuyArmed = false;
         return(true);
        }
      return(false);
     }

   if(w.zOppBuyArmed && v > lvl40 && v > vOlder)
     {
      w.zOppBuyArmed = false;
      return(true);
     }
   w.zOppBuyArmed = false;
   return(false);
  }

// BUY→SELL: 60-65 bounce DOWN (loose overshoot OK). Deep spike above cancels.
bool PhStay_BounceSellFrom6065(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   const double lvl60 = cfg.bearCapLo - cfg.tol - PH_LOOP_EDGE; // 59
   const double deep  = cfg.bearCap + cfg.tol + PH_LOOP_OVERSHOOT;

   if(v + 1e-9 >= deep)
     {
      w.zOppSellArmed = false;
      return(false);
     }

   if(PhStay_In6065Loose(cfg,v))
     {
      if(!w.zOppSellArmed)
        {
         if(vOlder < lvl60)
            w.zOppSellArmed = true;
         return(false);
        }
      if(v < vOlder)
        {
         w.zOppSellArmed = false;
         return(true);
        }
      return(false);
     }

   if(w.zOppSellArmed && v < lvl60 && v < vOlder)
     {
      w.zOppSellArmed = false;
      return(true);
     }
   w.zOppSellArmed = false;
   return(false);
  }

bool PhStay_BounceBuyFrom50(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   if(!w.loop50Ready)
      return(false);
   const double mid   = PH_LOOP_50;
   const double band  = MathMax(PH_LOOP_50_BAND,cfg.tol);
   const double floor = cfg.bullHard - cfg.tol;
   const double cap   = cfg.bearCapLo - cfg.tol;

   if(v + 1e-9 < floor || v + 1e-9 >= cap)
     {
      w.loop50Armed = false;
      return(false);
     }
   if(!w.loop50Armed)
     {
      // 50 pe UPAR se aao — 35-40 wiggle ≠ 50 bounce
      if(vOlder > mid + band && v <= mid + cfg.tol + 1e-9)
         w.loop50Armed = true;
      return(false);
     }
   if(v > vOlder)
     {
      w.loop50Armed = false;
      w.loop50Ready = false;
      return(true);
     }
   return(false);
  }

bool PhStay_RejectSellFrom50(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   if(!w.loop50Ready)
      return(false);
   const double mid   = PH_LOOP_50;
   const double band  = MathMax(PH_LOOP_50_BAND,cfg.tol);
   const double floor = cfg.bullFloor + cfg.tol;
   const double cap   = cfg.bearCap + cfg.tol;

   if(v > cap + 1e-9 || v + 1e-9 < floor)
     {
      w.loop50Armed = false;
      return(false);
     }
   if(!w.loop50Armed)
     {
      if(vOlder < mid - band && v + 1e-9 >= mid - cfg.tol)
         w.loop50Armed = true;
      else if(v + 1e-9 >= mid - cfg.tol)
         w.loop50Armed = true;
      return(false);
     }
   if(v < vOlder)
     {
      w.loop50Armed = false;
      w.loop50Ready = false;
      return(true);
     }
   return(false);
  }

// Cross 65 up → arm.
// BUY flip ONLY if RSI reclaims 65 after 60-65 pullback (60-65 tick ≠ BUY).
bool PhStay_BuyConfirm(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder,
                       const bool canFlip)
  {
   const double lvl65 = cfg.bearCap - PH_LOOP_EDGE; // 64=65
   const double lvl60 = cfg.bearCapLo - cfg.tol - PH_LOOP_EDGE; // 59
   const bool   at65  = (v + 1e-9 >= lvl65);

   if(vOlder < lvl65 && at65)
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

   if(PhStay_In6065Loose(cfg,v))
      w.zBuyRetest = true;
   if(at65 && v < vOlder)
      w.zBuyPullback = true;

   if(w.zBuyAge < MathMax(2,cfg.confirmBars))
      return(false);

   bool want = false;
   if(w.zBuyRetest && at65 && v > vOlder)
      want = true;
   else if(!w.zBuyRetest && w.zBuyPullback && at65 && v > vOlder)
      want = true;

   if(!want)
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
