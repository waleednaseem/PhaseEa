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
   int      loopStep;       // 0-1-2: 0=regular Div, 1=opp-zone, 2=latched until Div
   int      loopPath;       // +1=div <35 (1=60-65,2=35-40); -1=div >65 (1=35-40,2=60-65)
   bool     loopDead;       // far-side through → no 1/2 until next regular Div
   int      loopFarAge;
   bool     loopHiSeen;     // tagged 59-65, wait reject down
   bool     loopLoSeen;     // tagged 35-40, wait bounce up
   bool     loopLoCross;    // 35 cross — sharp-up ≤3 bars
   int      loopLoCrossAge;
   double   loopLoCrossExt;
   // Sharp S&R (PriceSR dotted) for loop step 1/2 — stay = park too long
   bool     loopSrArmed;
   bool     loopSrIsSup;
   double   loopSrLvl;
   int      loopSrPark;
   // Step-1 extreme: reject peak → break UP invalidates; bounce trough → break DOWN invalidates
   double   loopStep1Ext;
   bool     loopStep1Peak;  // true=reject (60-65), false=bounce (35-40)
   datetime loopStep1Time;
   bool     loopEvt0;       // stamp 0 (regular Div pivot — not 35-40 / 60-65)
   datetime loopEvt0Time;
   double   loopEvt0Rsi;
   bool     loopEvt1;
   bool     loopEvt2;
   datetime loopEvt2Time;   // Complete2 bar — late Div se pehle galat 2 hatao
   datetime loopEvt2Stamp;  // pehla 2 label — replace pe move nahi
   double   loopEvt2Rsi;    // 2 extreme: SELL=peak, BUY=trough — break = against flip
   datetime loopKill1Time;  // 1 invalidate → remove stamp, no 0
   datetime loopKill2Time;  // late-Div race: galat 2 stamp delete
   bool     loop50Armed;
   bool     loop50Ready;
   bool     loop50Flipped; // pehla 2 pe 50 flip ho chuka
   bool     loopLatch;      // 2 complete → flip locked until next regular Div
   bool     loop2Hold;     // 2 ke baad: 50-zone se pehle against-2 → dubara flip
   bool     loop2MidSeen;  // 2 ke baad 50 cross
   bool     loop2Safe;     // 50 + agla zone (cross/bounce) → against-2 band
   int      loop2Reps;     // 0=pehla 2 (50 OK); 1=last replace (50 off)
   bool     loop2RepArm;   // <35 / >65 dekha, wait clean V
   int      loop2RepStay;
   int      loop3540Stay;  // step1: 35-40 andar bars (stay → DIE)
   bool     loop3540Seen;  // step1 ke baad 35-40 visit
   bool     loop3540Left;  // 35-40 se nikal ke wapas = re-cross DIE
  };

#define PH_SR_MAX 256
#define PH_ZONE_STAY_BARS 5
#define PH_LOOP_2_REPLACES 1  // pehla 2 ke baad ek replace, phir last
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
   w.loopPath         = 0;
   w.loopDead         = false;
   w.loopFarAge       = 0;
   w.loopHiSeen       = false;
   w.loopLoSeen       = false;
   w.loopLoCross      = false;
   w.loopLoCrossAge   = 0;
   w.loopLoCrossExt   = 0.0;
   w.loopSrArmed      = false;
   w.loopSrIsSup      = false;
   w.loopSrLvl        = 0.0;
   w.loopSrPark       = 0;
   w.loopStep1Ext     = 0.0;
   w.loopStep1Peak    = false;
   w.loopStep1Time    = 0;
   w.loopEvt0         = false;
   w.loopEvt0Time     = 0;
   w.loopEvt0Rsi      = 0.0;
   w.loopEvt1         = false;
   w.loopEvt2         = false;
   w.loopEvt2Time     = 0;
   w.loopEvt2Stamp    = 0;
   w.loopEvt2Rsi      = 0.0;
   w.loopKill1Time    = 0;
   w.loopKill2Time    = 0;
   w.loop50Armed      = false;
   w.loop50Ready      = false;
   w.loop50Flipped     = false;
   w.loopLatch        = false;
   w.loop2Hold        = false;
   w.loop2MidSeen     = false;
   w.loop2Safe        = false;
   w.loop2Reps        = 0;
   w.loop2RepArm      = false;
   w.loop2RepStay     = 0;
   w.loop3540Stay     = 0;
   w.loop3540Seen     = false;
   w.loop3540Left     = false;
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

void PhWalkClearLoopLoCross(SPhWalk &w)
  {
   w.loopLoCross    = false;
   w.loopLoCrossAge = 0;
   w.loopLoCrossExt = 0.0;
  }

void PhWalkClearLoop3540(SPhWalk &w)
  {
   w.loop3540Stay = 0;
   w.loop3540Seen = false;
   w.loop3540Left = false;
  }

void PhWalkClearZoneStay(SPhWalk &w)
  {
   PhWalkClearZoneBuy(w);
   PhWalkClearZoneSell(w);
   w.zOppBuyArmed  = false;
   w.zOppSellArmed = false;
   w.loop50Armed   = false;
   PhWalkClearLoopSr(w);
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
#define PH_LOOP_SHARP_BARS 3  // sharp reverse max bars (35-up / 65-down)
#define PH_LOOP_50       50.0
#define PH_LOOP_50_LO    48.0   // 50-zone low (yellow)
#define PH_LOOP_50_HI    53.0   // 50-zone high (yellow)
#define PH_LOOP_50_BAND  2.5    // legacy half-width (~48–53); prefer LO/HI

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

bool PhStay_LoopRsiInBounceZone(const SPhConfig &cfg,const double rsi)
  {
   return(PhStay_In3540(cfg,rsi) || PhStay_In6065(cfg,rsi));
  }

void PhStay_LoopDie(SPhWalk &w)
  {
   if(w.loopStep1Time > 0)
      w.loopKill1Time = w.loopStep1Time;
   if(w.loopEvt2Stamp > 0)
      w.loopKill2Time = w.loopEvt2Stamp;
   else if(w.loopEvt2Time > 0)
      w.loopKill2Time = w.loopEvt2Time;
   Print("Phase Loop: DIE path=",w.loopPath," stepWas=",w.loopStep);
   w.loopDead      = true;
   w.loopFarAge    = 0;
   w.loopHiSeen    = false;
   w.loopLoSeen    = false;
   PhWalkClearLoopLoCross(w);
   w.loopStep      = 0;
   w.loop50Ready   = false;
   w.loop50Armed   = false;
   w.loop50Flipped = false;
   w.loopLatch     = false;
   w.loop2Hold     = false;
   w.loop2MidSeen  = false;
   w.loop2Safe     = false;
   w.loop2Reps     = 0;
   w.loop2RepArm   = false;
   w.loop2RepStay  = 0;
   w.loopEvt1      = false;
   w.loopEvt2      = false;
   w.loopEvt2Time  = 0;
   w.loopEvt2Stamp = 0;
   w.loopEvt2Rsi   = 0.0;
   w.zOppBuyArmed  = false;
   w.zOppSellArmed = false;
   PhWalkClearLoopSr(w);
   PhWalkClearLoopStep1(w);
   PhWalkClearLoop3540(w);
  }

void PhStay_LoopComplete2(SPhWalk &w,const double v,const double vOlder,const datetime barT)
  {
   w.loopEvt2      = true;
   w.loopEvt2Time  = barT;
   w.loopEvt2Stamp = barT;
   w.loopEvt2Rsi   = (w.loopPath < 0) ? MathMax(v,vOlder) : MathMin(v,vOlder);
   w.loop50Ready   = true;   // 2 ke baad: 50 reject→SELL / bounce→BUY
   w.loop50Armed   = false;
   w.loop50Flipped = false;
   w.loopLatch     = true;   // classic 35/65 block; 50 switch OK
   w.loop2Hold     = true;
   w.loop2MidSeen  = false;
   w.loop2Safe     = false;
   w.loop2Reps     = 0;
   w.loop2RepArm   = false;
   w.loop2RepStay  = 0;
   w.loopStep      = 2;
   w.loopFarAge    = 0;
   w.loopHiSeen    = false;
   w.loopLoSeen    = false;
   PhWalkClearLoopLoCross(w);
   w.zOppBuyArmed  = false;
   w.zOppSellArmed = false;
   PhWalkClearLoopSr(w);
   PhWalkClearLoopStep1(w);
   PhWalkClearLoop3540(w);
   Print("Phase Loop: 2 path=",w.loopPath," @ ",TimeToString(barT));
  }

// 2 ke baad 50 cross = against-2 band (agla zone optional).
void PhStay_Loop2Confirm(SPhWalk &w,const double v,const datetime barT)
  {
   if(w.loopStep != 2 || w.loopPath == 0 || w.loop2Safe)
      return;
   if(barT != 0 && barT == w.loopEvt2Time)
      return;

   if(w.loopPath > 0)
     {
      if(v + 1e-9 >= PH_LOOP_50)
        {
         w.loop2MidSeen = true;
         w.loop2Safe    = true;
         Print("Phase Loop: 2 confirmed 50 — against off @ ",TimeToString(barT));
        }
     }
   else if(v <= PH_LOOP_50 + 1e-9)
     {
      w.loop2MidSeen = true;
      w.loop2Safe    = true;
      Print("Phase Loop: 2 confirmed 50 — against off @ ",TimeToString(barT));
     }
  }

// 2 ke baad market khilaaf: 2 RSI extreme todna = flip (pehla 2 bhi).
// SELL 2: peak se upar + rising → BUY. BUY 2: trough se neeche + falling → SELL.
int PhStay_LoopAgainst2(SPhWalk &w,const SPhConfig &cfg,const double v,
                        const double vOlder,const datetime barT)
  {
   if(w.loopStep != 2 || w.loopPath == 0 || w.loopEvt2Rsi <= 0.0)
      return(0);
   if(w.loop2Safe)
      return(0);
   if(barT != 0 && barT == w.loopEvt2Time)
      return(0);

   const double tol = cfg.tol;

   if(w.loopPath < 0 && v > w.loopEvt2Rsi + tol && v > vOlder)
     {
      w.loop2Hold     = false;
      w.loop2RepArm   = false;
      w.loop50Armed   = false;
      w.loop50Ready   = false;
      w.loop50Flipped = true;
      w.loop2Safe     = true;                 // against done
      w.loop2Reps     = PH_LOOP_2_REPLACES;   // replace/flip band until next Div
      w.loopLatch     = true;
      Print("Phase Loop: 2 against SELL → BUY rsi=",DoubleToString(v,1),
            " broke=",DoubleToString(w.loopEvt2Rsi,1)," @ ",TimeToString(barT));
      return(1);
     }
   if(w.loopPath > 0 && v < w.loopEvt2Rsi - tol && v < vOlder)
     {
      w.loop2Hold     = false;
      w.loop2RepArm   = false;
      w.loop50Armed   = false;
      w.loop50Ready   = false;
      w.loop50Flipped = true;
      w.loop2Safe     = true;
      w.loop2Reps     = PH_LOOP_2_REPLACES;
      w.loopLatch     = true;
      Print("Phase Loop: 2 against BUY → SELL rsi=",DoubleToString(v,1),
            " broke=",DoubleToString(w.loopEvt2Rsi,1)," @ ",TimeToString(barT));
      return(-1);
     }
   return(0);
  }

bool PhStay_CandleUpThenDown(const datetime barT)
  {
   int sh = iBarShift(_Symbol,_Period,barT,false);
   if(sh < 0) sh = 1;
   const double o1 = iOpen(_Symbol,_Period,sh);
   const double c1 = iClose(_Symbol,_Period,sh);
   const double o2 = iOpen(_Symbol,_Period,sh + 1);
   const double c2 = iClose(_Symbol,_Period,sh + 1);
   return(c2 > o2 && c1 < o1);
  }

bool PhStay_CandleDownThenUp(const datetime barT)
  {
   int sh = iBarShift(_Symbol,_Period,barT,false);
   if(sh < 0) sh = 1;
   const double o1 = iOpen(_Symbol,_Period,sh);
   const double c1 = iClose(_Symbol,_Period,sh);
   const double o2 = iOpen(_Symbol,_Period,sh + 1);
   const double c2 = iClose(_Symbol,_Period,sh + 1);
   return(c2 < o2 && c1 > o1);
  }

void PhStay_LoopReStamp2(SPhWalk &w,const double v,const double vOlder,const datetime barT)
  {
   // pehla 2 label lock — against/replace pe move nahi
   w.loopEvt2      = false;
   w.loopEvt2Time  = barT;
   w.loopEvt2Rsi   = (w.loopPath < 0) ? MathMax(v,vOlder) : MathMin(v,vOlder);
   w.loop2Reps     = PH_LOOP_2_REPLACES;
   w.loop50Ready   = false;   // 2nd 2: 50 flip band
   w.loop50Armed   = false;
   w.loop2Hold     = false;
   w.loop2MidSeen  = false;
   w.loop2Safe     = false;
   w.loop2RepArm   = false;
   w.loop2RepStay  = 0;
   w.loopLatch     = true;
   w.loopStep      = 2;
   Print("Phase Loop: 2 replace path=",w.loopPath," @ ",TimeToString(barT));
  }

// Pehla 2 ke baad: <35 se seedha up (no up-then-down) = 2 replace → BUY.
// >65 se seedha down (no down-then-up) = 2 replace → SELL. Ek dafa last.
int PhStay_LoopReplace2(SPhWalk &w,const SPhConfig &cfg,const double v,
                        const double vOlder,const datetime barT)
  {
   if(w.loopStep != 2 || w.loopPath == 0)
      return(0);
   if(w.loop2Reps >= PH_LOOP_2_REPLACES)
      return(0);
   if(barT != 0 && barT == w.loopEvt2Time)
      return(0);

   if(w.loopPath > 0)
     {
      if(PhStay_Below35(cfg,v))
        {
         w.loop2RepArm = true;
         w.loop2RepStay++;
         return(0);
        }
      if(w.loop2RepArm && v > vOlder && !PhStay_CandleUpThenDown(barT))
        {
         PhStay_LoopReStamp2(w,v,vOlder,barT);
         return(1);
        }
      if(!PhStay_Below35(cfg,v))
         w.loop2RepStay = 0;
     }
   else
     {
      if(PhStay_Above65(cfg,v))
        {
         w.loop2RepArm = true;
         w.loop2RepStay++;
         return(0);
        }
      if(w.loop2RepArm && v < vOlder && !PhStay_CandleDownThenUp(barT))
        {
         PhStay_LoopReStamp2(w,v,vOlder,barT);
         return(-1);
        }
      if(!PhStay_Above65(cfg,v))
         w.loop2RepStay = 0;
     }
   return(0);
  }

// 0 = regular Div only. 1 pe Div aaye to 2 nahi — naya 0. Stamp 35-40/60-65 mein nahi.
bool PhStay_LoopTryMark0(SPhWalk &w,const SPhConfig &cfg,const double v,
                         const bool newBull,const bool newBear,
                         const datetime divT,const double divRsi,const datetime barT)
  {
   if(!newBull && !newBear)
      return(false);
   if(w.loopStep1Time > 0)
      w.loopKill1Time = w.loopStep1Time;
   // Div pivot pehle confirm baad: beech mein galat Complete2 → 2 stamp hatao
   const datetime t0 = (divT > 0 ? divT : barT);
   if(w.loopEvt2Stamp > 0 && t0 > 0 && w.loopEvt2Stamp > t0)
      w.loopKill2Time = w.loopEvt2Stamp;
   w.loopDead      = false;
   w.loopFarAge    = 0;
   w.loopHiSeen    = false;
   w.loopLoSeen    = false;
   PhWalkClearLoopLoCross(w);
   w.loopStep      = 0;
   w.loop50Ready   = false;
   w.loop50Armed   = false;
   w.loop50Flipped = false;
   w.loopLatch     = false;
   w.loop2Hold     = false;
   w.loop2MidSeen  = false;
   w.loop2Safe     = false;
   w.loop2Reps     = 0;
   w.loop2RepArm   = false;
   w.loop2RepStay  = 0;
   w.loopEvt2      = false;
   w.loopEvt2Time  = 0;
   w.loopEvt2Stamp = 0;
   w.loopEvt2Rsi   = 0.0;
   w.zOppBuyArmed  = false;
   w.zOppSellArmed = false;
   PhWalkClearLoopSr(w);
   PhWalkClearLoopStep1(w);
   PhWalkClearLoop3540(w);

   const double sideRsi = (divRsi > 0.0 ? divRsi : v);
   if(newBull)
      w.loopPath = 1;
   else if(newBear)
      w.loopPath = -1;
   else if(sideRsi <= cfg.bullHard + cfg.tol + 1e-9)
      w.loopPath = 1;
   else
      w.loopPath = -1;

   w.loopEvt0Time = t0;
   w.loopEvt0Rsi  = (divRsi > 0.0 ? divRsi : v);
   w.loopEvt0     = true;   // 0 hamesha stamp (zone andar bhi)
   Print("Phase Loop: 0 DIV path=",w.loopPath," rsi=",DoubleToString(w.loopEvt0Rsi,1),
         " @ ",TimeToString(w.loopEvt0Time)," kill2=",(w.loopKill2Time > 0 ? 1 : 0));
   return(true);
  }

void PhStay_LoopSet1(SPhWalk &w,const double v,const double vOlder,
                     const bool isPeakReject,const datetime barT)
  {
   w.loopStep      = 1;
   w.loopStep1Peak = isPeakReject;
   w.loopStep1Ext  = isPeakReject ? MathMax(v,vOlder) : MathMin(v,vOlder);
   w.loopStep1Time = barT;
   w.loopEvt1      = true;
   w.loopFarAge    = 0;
   w.loopHiSeen    = false;
   PhWalkClearLoopLoCross(w);
   PhWalkClearLoop3540(w);
   Print("Phase Loop: 1 ",(isPeakReject ? "60-65" : "35-40"),
         " path=",w.loopPath," rsi=",DoubleToString(v,1)," @ ",TimeToString(barT));
  }

// 35 cross → sharp-up ≤3 bars (step 1 path>65 / step 2 path<35)
bool PhStay_LoopLoSharpUp(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   const double lvl35 = cfg.bullHard - cfg.tol;

   if(vOlder + 1e-9 >= lvl35 && v <= lvl35 + 1e-9)
     {
      w.loopLoCross    = true;
      w.loopLoCrossAge = 1;
      w.loopLoCrossExt = v;
      return(false);
     }

   if(!w.loopLoCross)
     {
      if(PhStay_Below35(cfg,v))
        {
         w.loopLoCross    = true;
         w.loopLoCrossAge = 1;
         w.loopLoCrossExt = v;
        }
      return(false);
     }

   w.loopLoCrossAge++;
   w.loopLoCrossExt = MathMin(w.loopLoCrossExt,v);

   if(v > vOlder)
     {
      const double minUp = MathMax(1.0,cfg.tol);
      if(v > lvl35 + 1e-9 || v >= w.loopLoCrossExt + minUp)
        {
         PhWalkClearLoopLoCross(w);
         return(true);
        }
     }

   if(w.loopLoCrossAge > PH_LOOP_SHARP_BARS)
      return(false);
   return(false);
  }

bool PhStay_LoopLoSharpTimedOut(SPhWalk &w)
  {
   return(w.loopLoCross && w.loopLoCrossAge > PH_LOOP_SHARP_BARS);
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
   PhWalkClearLoop3540(w);
   return(true);
  }

// Step 1 ke baad: 35-40 re-cross / park → DIE (BUY+SELL). <35 alag DIE.
bool PhStay_LoopFail3540After1(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   if(w.loopStep != 1)
      return(false);
   if(PhStay_In3540(cfg,v))
     {
      if(w.loop3540Left)
        {
         Print("Phase Loop: DIE 35-40 re-cross path=",w.loopPath,
               " rsi=",DoubleToString(v,1));
         PhStay_LoopDie(w);
         return(true);
        }
      w.loop3540Seen = true;
      w.loop3540Stay++;
      if(w.loop3540Stay >= PH_ZONE_STAY_BARS)
        {
         Print("Phase Loop: DIE 35-40 stay path=",w.loopPath,
               " bars=",w.loop3540Stay);
         PhStay_LoopDie(w);
         return(true);
        }
      return(false);
     }
   if(w.loop3540Seen)
      w.loop3540Left = true;
   w.loop3540Stay = 0;
   return(false);
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
   // SELL after 2: wait 48–53 bounce UP → BUY. Through <48 = no flip.
   if(!w.loop50Ready || w.loop2Reps >= PH_LOOP_2_REPLACES || w.loop50Flipped)
      return(false);
   const double mid = PH_LOOP_50;
   const double lo  = PH_LOOP_50_LO; // 48
   const double hi  = PH_LOOP_50_HI; // 53

   if(v + 1e-9 < lo && !w.loop50Armed)
     {
      if(vOlder + 1e-9 >= mid)
        {
         w.loop50Ready = false;
         return(false);
        }
     }
   if(w.loop50Armed && v + 1e-9 < lo)
     {
      w.loop50Armed = false;
      w.loop50Ready = false;
      return(false);
     }

   if(!w.loop50Armed)
     {
      if(v + 1e-9 >= lo && v <= hi + 1e-9 && vOlder > mid)
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
   // BUY after 2: wait 48–53 reject DOWN → SELL. Through >53 = no flip.
   if(!w.loop50Ready || w.loop2Reps >= PH_LOOP_2_REPLACES || w.loop50Flipped)
      return(false);
   const double mid = PH_LOOP_50;
   const double lo  = PH_LOOP_50_LO;
   const double hi  = PH_LOOP_50_HI;

   if(v > hi + 1e-9)
     {
      w.loop50Armed = false;
      w.loop50Ready = false;
      return(false);
     }

   if(!w.loop50Armed)
     {
      if(v + 1e-9 >= lo && v <= hi + 1e-9 && vOlder < mid)
         w.loop50Armed = true;
      else if(vOlder < mid && v + 1e-9 >= lo && v <= hi + 1e-9)
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
