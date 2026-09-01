//+------------------------------------------------------------------+
//|                                            Phase_PriceSR.mqh     |
//| Extra RSI S&R: last N bars RSI swing H/L — dotted, trade-only    |
//| Scan independent of RSI window; arm on touch → fire on bounce    |
//+------------------------------------------------------------------+
#ifndef PHASE_PRICE_SR_MQH
#define PHASE_PRICE_SR_MQH

#include "Phase_Types.mqh"
#include "Phase_SR.mqh"
#include "Phase_Trade.mqh"

#define PH_PSR_MAX 64

struct SPhPriceLevel
  {
   double   level;      // RSI level
   datetime barTime;
   bool     isSupport;
  };

struct SPhPriceSR
  {
   SPhPriceLevel lvl[PH_PSR_MAX];
   int           count;
   datetime      lastFireBar;
   double        lastFireLevel;
   // arm on zone touch → fire on RSI move away (like PhTrade_CheckBounce)
   bool          armed;
   bool          armedIsSupport;
   double        armedLevel;
   string        drawn[PH_PSR_MAX];
   int           drawnN;
  };

void PhPriceSR_Init(SPhPriceSR &st)
  {
   st.count = 0;
   st.lastFireBar = 0;
   st.lastFireLevel = 0.0;
   st.armed = false;
   st.armedIsSupport = false;
   st.armedLevel = 0.0;
   st.drawnN = 0;
  }

void PhPriceSR_ClearArm(SPhPriceSR &st)
  {
   st.armed = false;
   st.armedIsSupport = false;
   st.armedLevel = 0.0;
  }

void PhPriceSR_DeleteTracked(SPhPriceSR &st)
  {
   for(int i = 0; i < st.drawnN; i++)
      ObjectDelete(0,st.drawn[i]);
   st.drawnN = 0;
  }

void PhPriceSR_DeleteObjects()
  {
   string tag = "PH_PSR_";
   int total = ObjectsTotal(0,-1,-1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0,i,-1,-1);
      if(StringFind(name,tag) == 0)
         ObjectDelete(0,name);
     }
  }

void PhPriceSR_DrawOne(SPhPriceSR &st,const int rsiWindow,const int idx,
                       const datetime t0,const datetime tNow,
                       const double lvl,const bool isSupport)
  {
   if(rsiWindow < 0 || st.drawnN >= PH_PSR_MAX)
      return;
   string nm = isSupport
               ? ("PH_PSR_S" + IntegerToString(idx))
               : ("PH_PSR_R" + IntegerToString(idx));
   if(ObjectFind(0,nm) < 0)
     {
      if(!ObjectCreate(0,nm,OBJ_TREND,rsiWindow,t0,lvl,tNow,lvl))
         return;
     }
   else
     {
      ObjectMove(0,nm,0,t0,lvl);
      ObjectMove(0,nm,1,tNow,lvl);
     }
   ObjectSetInteger(0,nm,OBJPROP_COLOR,isSupport ? clrAqua : clrOrangeRed);
   ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,true);
   ObjectSetInteger(0,nm,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,nm,OBJPROP_BACK,true);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
   st.drawn[st.drawnN++] = nm;
  }

bool PhPriceSR_LevelsEqual(const SPhPriceSR &st,const SPhPriceLevel &neu[],const int neuN)
  {
   if(st.count != neuN)
      return(false);
   const double tol = 0.01;
   for(int i = 0; i < neuN; i++)
     {
      if(st.lvl[i].isSupport != neu[i].isSupport)
         return(false);
      if(MathAbs(st.lvl[i].level - neu[i].level) > tol)
         return(false);
      if(st.lvl[i].barTime != neu[i].barTime)
         return(false);
     }
   return(true);
  }

bool PhPriceSR_NearLevel(const double r1,const double r2,const double lvl,const double tol)
  {
   if(MathAbs(r1 - lvl) <= tol || MathAbs(r2 - lvl) <= tol)
      return(true);
   // crossed / spanned the level between r2→r1
   if(MathMin(r1,r2) <= lvl + tol && MathMax(r1,r2) >= lvl - tol)
      return(true);
   return(false);
  }

// Extra S&R on RSI pane (dotted) — levels always scanned; draw only if window ok
void PhPriceSR_Scan(SPhPriceSR &st,const double &rsi[],const datetime &times[],
                    const int rsiWindow,const int lookback=100,const int str=2,
                    const bool draw=true)
  {
   SPhPriceLevel neu[PH_PSR_MAX];
   int neuN = 0;

   int n = ArraySize(rsi);
   int hi = MathMin(lookback,n - str - 1);
   if(hi < str + 2)
     {
      if(st.count > 0 || st.drawnN > 0)
        {
         PhPriceSR_DeleteTracked(st);
         PhPriceSR_DeleteObjects();
         st.count = 0;
         PhPriceSR_ClearArm(st);
        }
      return;
     }

   datetime tNow = (ArraySize(times) > 1 ? times[1] : TimeCurrent());
   const double dupTol = 1.0;
   const bool canDraw = (draw && rsiWindow >= 0);

   for(int s = str + 1; s <= hi; s++)
     {
      if(PhIsSwingLow(rsi,s,hi + str,str))
        {
         if(neuN >= PH_PSR_MAX) break;
         double lvl = rsi[s];
         if(lvl >= 35.0) continue;
         bool dup = false;
         for(int d = 0; d < neuN; d++)
           {
            if(neu[d].isSupport && MathAbs(neu[d].level - lvl) <= dupTol)
              { dup = true; break; }
           }
         if(dup) continue;
         datetime t0 = (s < ArraySize(times) ? times[s] : 0);
         if(t0 <= 0) continue;
         neu[neuN].level = lvl;
         neu[neuN].barTime = t0;
         neu[neuN].isSupport = true;
         neuN++;
        }

      if(PhIsSwingHigh(rsi,s,hi + str,str))
        {
         if(neuN >= PH_PSR_MAX) break;
         double lvl = rsi[s];
         if(lvl <= 65.0) continue;
         bool dup = false;
         for(int d = 0; d < neuN; d++)
           {
            if(!neu[d].isSupport && MathAbs(neu[d].level - lvl) <= dupTol)
              { dup = true; break; }
           }
         if(dup) continue;
         datetime t0 = (s < ArraySize(times) ? times[s] : 0);
         if(t0 <= 0) continue;
         neu[neuN].level = lvl;
         neu[neuN].barTime = t0;
         neu[neuN].isSupport = false;
         neuN++;
        }
     }

   // Same levels + already drawn → only extend ray end
   if(canDraw && PhPriceSR_LevelsEqual(st,neu,neuN) && st.drawnN == neuN)
     {
      for(int i = 0; i < st.drawnN; i++)
        {
         if(ObjectFind(0,st.drawn[i]) >= 0)
            ObjectMove(0,st.drawn[i],1,tNow,st.lvl[i].level);
        }
      return;
     }

   // Levels unchanged, no draw needed (window missing or draw off) → keep count
   if(!canDraw && PhPriceSR_LevelsEqual(st,neu,neuN))
     {
      if(st.drawnN > 0)
        {
         PhPriceSR_DeleteTracked(st);
         PhPriceSR_DeleteObjects();
        }
      return;
     }

   PhPriceSR_DeleteTracked(st);
   if(!canDraw)
      PhPriceSR_DeleteObjects();

   st.count = neuN;
   for(int i = 0; i < neuN; i++)
     {
      st.lvl[i] = neu[i];
      if(canDraw)
         PhPriceSR_DrawOne(st,rsiWindow,i,neu[i].barTime,tNow,
                           neu[i].level,neu[i].isSupport);
     }
  }

// Closed bar: arm on level touch → fire on bounce/reject (regime-aligned)
void PhPriceSR_CheckTrade(SPhPriceSR &st,SPhTradeState &trade,const SPhTradeCfg &cfg,
                          const ENUM_PH_REGIME regime,const double &rsi[])
  {
   if(!cfg.enable || regime == PH_NEUTRAL)
     {
      PhPriceSR_ClearArm(st);
      return;
     }
   if(PhTrade_IsLocked(trade))
      return;
   if(ArraySize(rsi) < 3 || st.count <= 0)
      return;

   datetime barT = iTime(_Symbol,_Period,1);
   if(barT <= 0 || barT == st.lastFireBar)
      return;

   const double r1 = rsi[1];
   const double r2 = rsi[2];
   const double tol = MathMax(0.5,cfg.zoneTol);

   if(regime == PH_BULLISH)
     {
      if(st.armed && !st.armedIsSupport)
         PhPriceSR_ClearArm(st);

      // Fire 1: prior arm + bounce up (even if RSI left the level)
      if(st.armed && st.armedIsSupport && r1 > r2)
        {
         if(PhTrade_Open(trade,cfg,ORDER_TYPE_BUY,"PH_PSR"))
           {
            Print("Phase ExtraSR: BUY bounce RSI@",DoubleToString(st.armedLevel,1),
                  " r1=",DoubleToString(r1,2)," r2=",DoubleToString(r2,2));
            st.lastFireBar = barT;
            st.lastFireLevel = st.armedLevel;
           }
         PhPriceSR_ClearArm(st);
         return;
        }

      // Fire 2 / arm: touch support this bar
      bool got = false;
      for(int i = 0; i < st.count; i++)
        {
         if(!st.lvl[i].isSupport) continue;
         if(!PhPriceSR_NearLevel(r1,r2,st.lvl[i].level,tol))
            continue;
         // same-bar touch + bounce
         if(r1 > r2)
           {
            if(PhTrade_Open(trade,cfg,ORDER_TYPE_BUY,"PH_PSR"))
              {
               Print("Phase ExtraSR: BUY bounce RSI@",DoubleToString(st.lvl[i].level,1),
                     " r1=",DoubleToString(r1,2)," r2=",DoubleToString(r2,2));
               st.lastFireBar = barT;
               st.lastFireLevel = st.lvl[i].level;
              }
            PhPriceSR_ClearArm(st);
            return;
           }
         st.armed = true;
         st.armedIsSupport = true;
         st.armedLevel = st.lvl[i].level;
         got = true;
         break;
        }
      if(!got)
         PhPriceSR_ClearArm(st);
     }
   else if(regime == PH_BEARISH)
     {
      if(st.armed && st.armedIsSupport)
         PhPriceSR_ClearArm(st);

      if(st.armed && !st.armedIsSupport && r1 < r2)
        {
         if(PhTrade_Open(trade,cfg,ORDER_TYPE_SELL,"PH_PSR"))
           {
            Print("Phase ExtraSR: SELL reject RSI@",DoubleToString(st.armedLevel,1),
                  " r1=",DoubleToString(r1,2)," r2=",DoubleToString(r2,2));
            st.lastFireBar = barT;
            st.lastFireLevel = st.armedLevel;
           }
         PhPriceSR_ClearArm(st);
         return;
        }

      bool got = false;
      for(int i = 0; i < st.count; i++)
        {
         if(st.lvl[i].isSupport) continue;
         if(!PhPriceSR_NearLevel(r1,r2,st.lvl[i].level,tol))
            continue;
         if(r1 < r2)
           {
            if(PhTrade_Open(trade,cfg,ORDER_TYPE_SELL,"PH_PSR"))
              {
               Print("Phase ExtraSR: SELL reject RSI@",DoubleToString(st.lvl[i].level,1),
                     " r1=",DoubleToString(r1,2)," r2=",DoubleToString(r2,2));
               st.lastFireBar = barT;
               st.lastFireLevel = st.lvl[i].level;
              }
            PhPriceSR_ClearArm(st);
            return;
           }
         st.armed = true;
         st.armedIsSupport = false;
         st.armedLevel = st.lvl[i].level;
         got = true;
         break;
        }
      if(!got)
         PhPriceSR_ClearArm(st);
     }
   else
      PhPriceSR_ClearArm(st);
  }

// --- 0-1-2 loop: sharp PriceSR bounce (not stay/park) ---
bool PhPriceSR_NearBandResist(const double lvl,const SPhConfig &cfg)
  {
   // resist >65 (dotted) — near 65 band
   return(lvl > cfg.bearCap - 1.0e-9);
  }

bool PhPriceSR_NearBandSupport(const double lvl,const SPhConfig &cfg)
  {
   // support <35 (dotted) — near 35 band (31/32 etc.)
   return(lvl < cfg.bullHard + 1.0e-9);
  }

bool PhPriceSR_LoopSharpRejectDown(SPhPriceSR &st,SPhWalk &w,SPhSRList &L,
                                   const SPhConfig &cfg,
                                   const double v,const double vOlder)
  {
   const double tol = MathMax(5.0,cfg.tol);
   bool nearAny = false;
   double hitLvl = 0.0;

   for(int i = 0; i < st.count; i++)
     {
      if(st.lvl[i].isSupport) continue;
      if(!PhPriceSR_NearBandResist(st.lvl[i].level,cfg)) continue;
      if(!PhPriceSR_NearLevel(v,vOlder,st.lvl[i].level,tol)) continue;
      nearAny = true;
      hitLvl = st.lvl[i].level;
      break;
     }

   if(!nearAny && w.invOn && w.invLevel + 1e-9 >= cfg.bearCap)
     {
      if(PhPriceSR_NearLevel(v,vOlder,w.invLevel,tol))
        {
         nearAny = true;
         hitLvl  = w.invLevel;
        }
     }

   if(!nearAny)
     {
      for(int j = 0; j < L.count; j++)
        {
         if(L.seg[j].isSupport) continue;
         if(L.seg[j].level0 + 1e-9 < cfg.bearCap) continue;
         if(!PhPriceSR_NearLevel(v,vOlder,L.seg[j].level0,tol)) continue;
         nearAny = true;
         hitLvl  = L.seg[j].level0;
         break;
        }
     }

   if(!nearAny)
     {
      if(w.loopSrArmed && !w.loopSrIsSup)
         PhWalkClearLoopSr(w);
      return(false);
     }

   if(!w.loopSrArmed || w.loopSrIsSup || MathAbs(w.loopSrLvl - hitLvl) > tol)
     {
      w.loopSrArmed = true;
      w.loopSrIsSup = false;
      w.loopSrLvl   = hitLvl;
      w.loopSrPark  = 1;
      // same bar touch + reject down
      if(v < vOlder)
        {
         PhWalkClearLoopSr(w);
         return(true);
        }
      return(false);
     }

   w.loopSrPark++;
   if(v < vOlder)
     {
      PhWalkClearLoopSr(w);
      return(true);
     }
   return(false);
  }

bool PhPriceSR_LoopSharpBounceUp(SPhPriceSR &st,SPhWalk &w,SPhSRList &L,
                                 const SPhConfig &cfg,
                                 const double v,const double vOlder)
  {
   const double tol = MathMax(5.0,cfg.tol);
   bool nearAny = false;
   double hitLvl = 0.0;

   for(int i = 0; i < st.count; i++)
     {
      if(!st.lvl[i].isSupport) continue;
      if(!PhPriceSR_NearBandSupport(st.lvl[i].level,cfg)) continue;
      if(!PhPriceSR_NearLevel(v,vOlder,st.lvl[i].level,tol)) continue;
      nearAny = true;
      hitLvl = st.lvl[i].level;
      break;
     }

   if(!nearAny && w.invOn && w.invLevel <= cfg.bullHard + 1e-9)
     {
      if(PhPriceSR_NearLevel(v,vOlder,w.invLevel,tol))
        {
         nearAny = true;
         hitLvl  = w.invLevel;
        }
     }

   if(!nearAny)
     {
      for(int j = 0; j < L.count; j++)
        {
         if(!L.seg[j].isSupport) continue;
         if(L.seg[j].level0 > cfg.bullHard + 1e-9) continue;
         if(!PhPriceSR_NearLevel(v,vOlder,L.seg[j].level0,tol)) continue;
         nearAny = true;
         hitLvl  = L.seg[j].level0;
         break;
        }
     }

   if(!nearAny)
     {
      if(w.loopSrArmed && w.loopSrIsSup)
         PhWalkClearLoopSr(w);
      return(false);
     }

   if(!w.loopSrArmed || !w.loopSrIsSup || MathAbs(w.loopSrLvl - hitLvl) > tol)
     {
      w.loopSrArmed = true;
      w.loopSrIsSup = true;
      w.loopSrLvl   = hitLvl;
      w.loopSrPark  = 1;
      if(v > vOlder)
        {
         PhWalkClearLoopSr(w);
         return(true);
        }
      return(false);
     }

   w.loopSrPark++;
   if(v > vOlder)
     {
      PhWalkClearLoopSr(w);
      return(true);
     }
   return(false);
  }

bool PhStay_LoopHasSupBelow35(SPhPriceSR &psr,SPhSRList &L,SPhWalk &w,const SPhConfig &cfg)
  {
   for(int i = 0; i < psr.count; i++)
     {
      if(!psr.lvl[i].isSupport) continue;
      if(psr.lvl[i].level < cfg.bullHard + 1e-9)
         return(true);
     }
   if(w.invOn && w.invLevel < cfg.bullHard + 1e-9)
      return(true);
   for(int j = 0; j < L.count; j++)
     {
      if(!L.seg[j].isSupport) continue;
      if(L.seg[j].level0 < cfg.bullHard + 1e-9)
         return(true);
     }
   return(false);
  }

bool PhStay_LoopHasResAbove65(SPhPriceSR &psr,SPhSRList &L,SPhWalk &w,const SPhConfig &cfg)
  {
   for(int i = 0; i < psr.count; i++)
     {
      if(psr.lvl[i].isSupport) continue;
      if(psr.lvl[i].level + 1e-9 >= cfg.bearCap)
         return(true);
     }
   if(w.invOn && w.invLevel + 1e-9 >= cfg.bearCap)
      return(true);
   for(int j = 0; j < L.count; j++)
     {
      if(L.seg[j].isSupport) continue;
      if(L.seg[j].level0 + 1e-9 >= cfg.bearCap)
         return(true);
     }
   return(false);
  }

double PhStay_LoopNearestResAbove65(SPhPriceSR &psr,SPhSRList &L,SPhWalk &w,const SPhConfig &cfg)
  {
   double hit = 0.0;
   for(int i = 0; i < psr.count; i++)
     {
      if(psr.lvl[i].isSupport) continue;
      if(psr.lvl[i].level + 1e-9 < cfg.bearCap) continue;
      if(hit <= 0.0 || psr.lvl[i].level < hit)
         hit = psr.lvl[i].level;
     }
   if(w.invOn && w.invLevel + 1e-9 >= cfg.bearCap)
     {
      if(hit <= 0.0 || w.invLevel < hit)
         hit = w.invLevel;
     }
   for(int j = 0; j < L.count; j++)
     {
      if(L.seg[j].isSupport) continue;
      if(L.seg[j].level0 + 1e-9 < cfg.bearCap) continue;
      if(hit <= 0.0 || L.seg[j].level0 < hit)
         hit = L.seg[j].level0;
     }
   return(hit);
  }

// fromLow: S&R through = dead; mere Above65 pe DIE nahi (warna 1 miss).
// no S&R: sirf deep overshoot through. fromHigh: Below35 = dead
// + 0 DIV extreme break: path-1 peak up / path+1 trough down → DIE (step 0/1)
void PhStay_LoopCheckFarKill(SPhWalk &w,SPhPriceSR &psr,SPhSRList &L,const SPhConfig &cfg,
                             const double v,const double vOlder)
  {
   if(w.loopDead || w.loopStep == 2 || w.loopPath == 0)
      return;

   if((w.loopStep == 0 || w.loopStep == 1) && w.loopEvt0Rsi > 0.0)
     {
      const double tol = MathMax(0.5,cfg.tol);
      if(w.loopPath < 0 && v > w.loopEvt0Rsi + tol)
        {
         PhStay_LoopDie(w);
         return;
        }
      if(w.loopPath > 0 && v < w.loopEvt0Rsi - tol)
        {
         PhStay_LoopDie(w);
         return;
        }
     }

   if(w.loopPath > 0)
     {
      if(w.loopSrArmed || w.loopHiSeen)
         return; // reject in progress
      if(PhStay_LoopHasResAbove65(psr,L,w,cfg))
        {
         if(!PhStay_Above65(cfg,v))
            return;
         const double hit = PhStay_LoopNearestResAbove65(psr,L,w,cfg);
         const double tol = MathMax(1.0,cfg.tol);
         if(hit > 0.0 && v > hit + tol && v >= vOlder)
            PhStay_LoopDie(w);
         return;
        }
      // no S&R: 60-65 zone reject ko time do — sirf deep through
      const double deep = cfg.bearCap + cfg.tol + PH_LOOP_OVERSHOOT;
      if(v > deep && v >= vOlder)
         PhStay_LoopDie(w);
     }
   else if(w.loopPath < 0)
     {
      // fromHigh: step1 ke baad 35 cross = dead; step0 pe sharp-up try
      if(w.loopStep >= 1 && PhStay_Below35(cfg,v))
         PhStay_LoopDie(w);
      else if(w.loopStep == 0 && PhStay_LoopLoSharpTimedOut(w))
         PhStay_LoopDie(w);
     }
  }

bool PhStay_LoopHiReject(SPhWalk &w,SPhPriceSR &psr,SPhSRList &L,
                         const SPhConfig &cfg,const double v,const double vOlder)
  {
   // agar 65+ pe real S&R hai → sharp reject; warna 60-65 hi S&R
   if(PhStay_LoopHasResAbove65(psr,L,w,cfg))
     {
      if(PhPriceSR_LoopSharpRejectDown(psr,w,L,cfg,v,vOlder))
         return(true);
     }

   const double lo = cfg.bearCapLo - PH_LOOP_EDGE; // 59 — 60 touch nahi, 59 OK
   const double hi = cfg.bearCap + cfg.tol + PH_LOOP_OVERSHOOT; // 65+slack
   const bool   inHi = (v + 1e-9 >= lo && v <= hi + 1e-9);

   // deep through bina zone/S&R reject
   if(v > hi + 1e-9)
     {
      w.loopHiSeen = false;
      return(false);
     }

   if(v + 1e-9 >= lo)
      w.loopHiSeen = true;

   if(inHi)
     {
      return(v < vOlder);
     }
   if(w.loopHiSeen && v < vOlder)
     {
      w.loopHiSeen = false;
      return(true);
     }
   if(v + 1e-9 < lo - 5.0)
      w.loopHiSeen = false;
   return(false);
  }

bool PhStay_LoopLoBounce(SPhWalk &w,SPhPriceSR &psr,SPhSRList &L,
                         const SPhConfig &cfg,const double v,const double vOlder)
  {
   // 35 sharp-up: cross neeche → fori reverse ≤3 bars
   if(PhStay_LoopLoSharpUp(w,cfg,v,vOlder))
      return(true);

   if(PhStay_Below35(cfg,v))
     {
      w.loopLoSeen = false;
      return(false);
     }

   PhWalkClearLoopLoCross(w);

   // real S&R <35: sirf jab RSI pehle se 35-40 band mein ho
   if(PhStay_In3540(cfg,v) && PhStay_LoopHasSupBelow35(psr,L,w,cfg))
     {
      if(PhPriceSR_LoopSharpBounceUp(psr,w,L,cfg,v,vOlder))
         return(true);
     }

   // warna 35-40 hi S&R
   const double bandHi = cfg.bullFloor + cfg.tol + PH_LOOP_EDGE; // 41
   const bool   inLo   = PhStay_In3540(cfg,v);

   if(inLo)
     {
      w.loopLoSeen = true;
      return(v > vOlder);
     }
   if(w.loopLoSeen && v > bandHi && v > vOlder)
     {
      w.loopLoSeen = false;
      return(true);
     }
   if(v > 50.0)
      w.loopLoSeen = false;
   return(false);
  }

int PhStay_LoopDrive(SPhWalk &w,SPhPriceSR &psr,SPhSRList &L,const SPhConfig &cfg,
                     const double v,const double vOlder,const datetime barT,
                     const bool newBull,const bool newBear,
                     const datetime divT,const double divRsi)
  {
   const bool just0 = PhStay_LoopTryMark0(w,cfg,v,newBull,newBear,divT,divRsi,barT);

   if(w.loopDead)
      return(0);

   // DIE pehle — 1 stamp/wait tabhi jab loop zinda
   PhStay_LoopCheckFarKill(w,psr,L,cfg,v,vOlder);
   if(w.loopDead)
      return(0);

   if(PhStay_LoopInvalidate1(w,cfg,v))
      return(0);

   // step 1: <35 stay/dump = DIE (dono path) — sharp-up se 2 nahi
   if(w.loopStep == 1 && PhStay_Below35(cfg,v))
     {
      Print("Phase Loop: DIE 35-stay path=",w.loopPath," rsi=",DoubleToString(v,1));
      PhStay_LoopDie(w);
      return(0);
     }

   if(just0)
      return(0);

   if(w.loopStep == 0 && w.loopPath != 0)
     {
      if(w.loopPath > 0)
        {
         if(PhStay_LoopHiReject(w,psr,L,cfg,v,vOlder))
            PhStay_LoopSet1(w,v,vOlder,true,barT);
        }
      else if(PhStay_LoopLoBounce(w,psr,L,cfg,v,vOlder))
         PhStay_LoopSet1(w,v,vOlder,false,barT);
     }

   if(w.loopStep == 1 && w.loopStep1Time != barT && w.loopEvt0Time > 0)
     {
      if(w.loopPath > 0)
        {
         if(PhStay_LoopLoBounce(w,psr,L,cfg,v,vOlder))
           {
            PhStay_LoopComplete2(w,v,vOlder,barT);
            return(1);
           }
        }
      else if(PhStay_LoopHiReject(w,psr,L,cfg,v,vOlder))
        {
         PhStay_LoopComplete2(w,v,vOlder,barT);
         return(-1);
        }
      if(PhStay_LoopFail3540After1(w,cfg,v))
         return(0);
     }

   if(w.loopStep == 2)
     {
      PhStay_Loop2Confirm(w,v,barT);
      const int against = PhStay_LoopAgainst2(w,cfg,v,vOlder,barT);
      if(against != 0)
         return(against);
      const int rep = PhStay_LoopReplace2(w,cfg,v,vOlder,barT);
      if(rep != 0)
         return(rep);
     }

   return(0);
  }

#endif
//+------------------------------------------------------------------+
