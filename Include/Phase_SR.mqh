//+------------------------------------------------------------------+
//|                                                 Phase_SR.mqh     |
//| INV — support <=25 (>20), resist >=70 (<80); prefer near 25/70   |
//+------------------------------------------------------------------+
#ifndef PHASE_SR_MQH
#define PHASE_SR_MQH

#include "Phase_Types.mqh"

bool PhIsSwingLow(const double &rsi[],const int shift,const int hist,const int str)
  {
   if(shift - str < 1 || shift + str > hist)
      return(false);
   const double v = rsi[shift];
   for(int k = 1; k <= str; k++)
     {
      if(rsi[shift - k] < v) return(false);
      if(rsi[shift + k] < v) return(false);
     }
   return(true);
  }

bool PhIsSwingHigh(const double &rsi[],const int shift,const int hist,const int str)
  {
   if(shift - str < 1 || shift + str > hist)
      return(false);
   const double v = rsi[shift];
   for(int k = 1; k <= str; k++)
     {
      if(rsi[shift - k] > v) return(false);
      if(rsi[shift + k] > v) return(false);
     }
   return(true);
  }

bool PhIsLocalHigh(const double &rsi[],const int shift,const int hist)
  {
   return(PhIsSwingHigh(rsi,shift,hist,1));
  }

bool PhIsLocalLow(const double &rsi[],const int shift,const int hist)
  {
   return(PhIsSwingLow(rsi,shift,hist,1));
  }

double PhInv_Gap(const SPhConfig &cfg)
  {
   return(MathMax(2.0,cfg.invGap));
  }

bool PhInv_OkSupport(const double lvl,const SPhConfig &cfg)
  {
   const double g = PhInv_Gap(cfg);
   // >20+g and never above invNearSup (25)
   return(lvl > cfg.rsiFloor + g && lvl <= cfg.invNearSup + 1.0e-9);
  }

bool PhInv_OkResist(const double lvl,const SPhConfig &cfg)
  {
   const double g = PhInv_Gap(cfg);
   // <80-g and never below invNearRes (70)
   return(lvl >= cfg.invNearRes - 1.0e-9 && lvl < cfg.rsiCeil - g);
  }

double PhInv_ClampSupport(const double raw,const SPhConfig &cfg)
  {
   const double g = PhInv_Gap(cfg);
   double lvl = raw;
   if(lvl < cfg.rsiFloor + g)
      lvl = cfg.rsiFloor + g;
   if(lvl > cfg.invNearSup)
      lvl = cfg.invNearSup;   // never above 25
   return(lvl);
  }

double PhInv_ClampResist(const double raw,const SPhConfig &cfg)
  {
   const double g = PhInv_Gap(cfg);
   double lvl = raw;
   if(lvl < cfg.invNearRes)
      lvl = cfg.invNearRes;   // never below 70
   if(lvl > cfg.rsiCeil - g)
      lvl = cfg.rsiCeil - g;
   return(lvl);
  }

bool PhInv_ResistPeakRaw(const double raw,const SPhConfig &cfg)
  {
   // above-65 zone: only peaks that can sit at/above 70
   const double g = PhInv_Gap(cfg);
   return(raw >= cfg.invNearRes - 1.0e-9 && raw < cfg.rsiCeil - g);
  }

bool PhInv_SupportTroughRaw(const double raw,const SPhConfig &cfg)
  {
   // below-35 zone: only troughs that can sit at/below 25
   const double g = PhInv_Gap(cfg);
   return(raw <= cfg.invNearSup + 1.0e-9 && raw > cfg.rsiFloor + g);
  }

bool PhResistPivot(const double &rsi[],const int s,const int hist,const int str)
  {
   if(PhIsSwingHigh(rsi,s,hist,str))
      return(true);
   if(str > 1 && PhIsLocalHigh(rsi,s,hist))
      return(true);
   return(false);
  }

bool PhSupportPivot(const double &rsi[],const int s,const int hist,const int str)
  {
   if(PhIsSwingLow(rsi,s,hist,str))
      return(true);
   if(str > 1 && PhIsLocalLow(rsi,s,hist))
      return(true);
   return(false);
  }

// NEAREST local/swing HIGH clearly >65 — clamp level <80
bool PhFindResistUTurn(const double &rsi[],const datetime &times[],
                       const int fromShift,const int hist,const SPhConfig &cfg,
                       double &lvl,datetime &tOut)
  {
   const int str = MathMax(1,cfg.swingStrength);
   const int maxS = MathMin(hist,fromShift + MathMax(20,cfg.invLookback));
   for(int s = fromShift; s <= maxS; s++)
     {
      const double raw = rsi[s];
      if(!PhInv_ResistPeakRaw(raw,cfg))
         continue;
      if(!PhResistPivot(rsi,s,hist,str))
         continue;
      lvl  = PhInv_ClampResist(raw,cfg);
      tOut = times[s];
      return(true);
     }
   return(false);
  }

// NEAREST local/swing LOW clearly <35 — clamp level >20
bool PhFindSupportUTurn(const double &rsi[],const datetime &times[],
                        const int fromShift,const int hist,const SPhConfig &cfg,
                        double &lvl,datetime &tOut)
  {
   const int str = MathMax(1,cfg.swingStrength);
   const int maxS = MathMin(hist,fromShift + MathMax(20,cfg.invLookback));
   for(int s = fromShift; s <= maxS; s++)
     {
      const double raw = rsi[s];
      if(!PhInv_SupportTroughRaw(raw,cfg))
         continue;
      if(!PhSupportPivot(rsi,s,hist,str))
         continue;
      lvl  = PhInv_ClampSupport(raw,cfg);
      tOut = times[s];
      return(true);
     }
   return(false);
  }

void PhInv_Set(SPhWalk &w,SPhSRList &L,const double lvl,const datetime t0,
               const datetime tNow,const bool isSupport,const SPhConfig &cfg)
  {
   double use = isSupport ? PhInv_ClampSupport(lvl,cfg) : PhInv_ClampResist(lvl,cfg);

   if(isSupport)
     {
      if(!PhInv_OkSupport(use,cfg))
         return;
     }
   else
     {
      if(!PhInv_OkResist(use,cfg))
         return;
     }

   w.invLevel = use;
   w.invTime  = t0;
   w.invOn    = true;
   PhWalkClearInvBreak(w);
   w.invSegIdx = PhSRListAdd(L,t0,tNow,use,isSupport);
  }

void PhInv_Close(SPhWalk &w,SPhSRList &L,const datetime tEnd)
  {
   if(w.invOn && w.invSegIdx >= 0 && tEnd != 0)
      PhSRListExtend(L,w.invSegIdx,tEnd);
   PhWalkClearInv(w);
  }

void PhInv_StartSell(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                     const int shift,const int hist,const SPhConfig &cfg)
  {
   PhWalkClearInv(w);
   double lvl;
   datetime tPivot;
   if(!PhFindResistUTurn(rsi,times,shift,hist,cfg,lvl,tPivot))
      return;
   PhInv_Set(w,L,lvl,times[shift],times[shift],false,cfg);
   w.invTime = tPivot;
  }

void PhInv_StartBuy(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                    const int shift,const int hist,const SPhConfig &cfg)
  {
   PhWalkClearInv(w);
   double lvl;
   datetime tPivot;
   if(!PhFindSupportUTurn(rsi,times,shift,hist,cfg,lvl,tPivot))
      return;
   PhInv_Set(w,L,lvl,times[shift],times[shift],true,cfg);
   w.invTime = tPivot;
  }

void PhInv_CaptureDuring(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                         const int shift,const int hist,const SPhConfig &cfg)
  {
   if(w.invOn)
      return;

   const int str = MathMax(1,cfg.swingStrength);
   const int piv = shift + str;
   if(piv + str > hist || piv - str < 1)
      return;
   if(w.regimeStartShift > 0 && piv > w.regimeStartShift)
      return;

   const double pv = rsi[piv];
   const datetime pt = times[piv];

   if(w.state == PH_BULLISH)
     {
      if(!PhInv_SupportTroughRaw(pv,cfg))
         return;
      if(!PhSupportPivot(rsi,piv,hist,str))
         return;
      PhInv_Set(w,L,pv,pt,times[shift],true,cfg);
     }
   else if(w.state == PH_BEARISH)
     {
      if(!PhInv_ResistPeakRaw(pv,cfg))
         return;
      if(!PhResistPivot(rsi,piv,hist,str))
         return;
      PhInv_Set(w,L,pv,pt,times[shift],false,cfg);
     }
  }

// After S&R: last N bars — prefer U-turn closest to 25 (sup) / 70 (res)
void PhInv_Refresh(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                   const int shift,const int hist,const SPhConfig &cfg)
  {
   if(!w.invOn || w.invSegIdx < 0)
      return;
   if(w.state != PH_BULLISH && w.state != PH_BEARISH)
      return;

   const int str = MathMax(1,cfg.swingStrength);
   const int win = MathMax(20,cfg.invRefreshBars);
   int maxS = MathMin(hist,shift + win);
   if(w.regimeStartShift > 0)
      maxS = MathMin(maxS,w.regimeStartShift);

   bool found = false;
   double bestRaw = 0.0;
   double bestDist = 1.0e9;
   datetime bestT = 0;

   for(int s = shift; s <= maxS; s++)
     {
      const double raw = rsi[s];
      if(w.state == PH_BEARISH)
        {
         if(!PhInv_ResistPeakRaw(raw,cfg))
            continue;
         if(!PhResistPivot(rsi,s,hist,str))
            continue;
         const double clamped = PhInv_ClampResist(raw,cfg);
         const double dist = MathAbs(clamped - cfg.invNearRes); // prefer near 70
         if(!found || dist < bestDist - 1.0e-9)
           {
            found    = true;
            bestDist = dist;
            bestRaw  = raw;
            bestT    = times[s];
           }
        }
      else
        {
         if(!PhInv_SupportTroughRaw(raw,cfg))
            continue;
         if(!PhSupportPivot(rsi,s,hist,str))
            continue;
         const double clamped = PhInv_ClampSupport(raw,cfg);
         const double dist = MathAbs(clamped - cfg.invNearSup); // prefer near 25
         if(!found || dist < bestDist - 1.0e-9)
           {
            found    = true;
            bestDist = dist;
            bestRaw  = raw;
            bestT    = times[s];
           }
        }
     }

   if(!found)
      return;

   const double use = (w.state == PH_BEARISH)
                      ? PhInv_ClampResist(bestRaw,cfg)
                      : PhInv_ClampSupport(bestRaw,cfg);
   if(w.state == PH_BEARISH)
     {
      if(!PhInv_OkResist(use,cfg))
         return;
     }
   else
     {
      if(!PhInv_OkSupport(use,cfg))
         return;
     }

   // only convert if new is closer to 25/70 than current
   const double curDist = (w.state == PH_BEARISH)
                          ? MathAbs(w.invLevel - cfg.invNearRes)
                          : MathAbs(w.invLevel - cfg.invNearSup);
   if(bestDist > curDist + 0.05)
      return;

   if(MathAbs(use - w.invLevel) >= 0.05)
      PhWalkClearInvBreak(w);

   w.invLevel = use;
   w.invTime  = bestT;
   PhSRListSetLevel(L,w.invSegIdx,use);
  }

void PhInv_Follow(SPhWalk &w,SPhSRList &L,const datetime tNow)
  {
   if(!w.invOn || w.invSegIdx < 0)
      return;
   PhSRListExtend(L,w.invSegIdx,tNow);
  }

#endif
//+------------------------------------------------------------------+
