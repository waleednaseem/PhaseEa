//+------------------------------------------------------------------+
//|                                                 Phase_SR.mqh     |
//| INV = U-turn RSI — find peak/bounce, clamp into (20+g .. 80-g)    |
//| Support: bounce clearly <35 | Resist: peak clearly >65           |
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
   return(lvl > cfg.rsiFloor + g && lvl < cfg.bullHard - g);
  }

bool PhInv_OkResist(const double lvl,const SPhConfig &cfg)
  {
   const double g = PhInv_Gap(cfg);
   return(lvl > cfg.bearCap + g && lvl < cfg.rsiCeil - g);
  }

double PhInv_ClampSupport(const double raw,const SPhConfig &cfg)
  {
   const double g = PhInv_Gap(cfg);
   double lvl = raw;
   if(lvl < cfg.rsiFloor + g)
      lvl = cfg.rsiFloor + g;
   if(lvl > cfg.bullHard - g)
      lvl = cfg.bullHard - g;
   return(lvl);
  }

double PhInv_ClampResist(const double raw,const SPhConfig &cfg)
  {
   const double g = PhInv_Gap(cfg);
   double lvl = raw;
   if(lvl < cfg.bearCap + g)
      lvl = cfg.bearCap + g;
   if(lvl > cfg.rsiCeil - g)
      lvl = cfg.rsiCeil - g;
   return(lvl);
  }

bool PhInv_ResistPeakRaw(const double raw,const SPhConfig &cfg)
  {
   return(raw > cfg.bearCap + PhInv_Gap(cfg));
  }

bool PhInv_SupportTroughRaw(const double raw,const SPhConfig &cfg)
  {
   return(raw < cfg.bullHard - PhInv_Gap(cfg));
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

void PhInv_Follow(SPhWalk &w,SPhSRList &L,const datetime tNow)
  {
   if(!w.invOn || w.invSegIdx < 0)
      return;
   PhSRListExtend(L,w.invSegIdx,tNow);
  }

#endif
//+------------------------------------------------------------------+
