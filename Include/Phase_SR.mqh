//+------------------------------------------------------------------+
//|                                                 Phase_SR.mqh     |
//| INV = exact U-turn RSI — NEVER at/near 35 or 65                  |
//| Support: bounce clearly <35 | Resist: HIGHEST peak clearly >65   |
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

double PhInv_Gap(const SPhConfig &cfg)
  {
   return(MathMax(2.0,cfg.invGap));
  }

bool PhInv_OkSupport(const double lvl,const SPhConfig &cfg)
  {
   return(lvl > 0.0 && lvl < cfg.bullHard - PhInv_Gap(cfg));
  }

bool PhInv_OkResist(const double lvl,const SPhConfig &cfg)
  {
   return(lvl > cfg.bearCap + PhInv_Gap(cfg) && lvl < 100.0);
  }

// HIGHEST swing HIGH clearly >65 in window — not the nearest weak spike
bool PhFindResistUTurn(const double &rsi[],const datetime &times[],
                       const int fromShift,const int hist,const SPhConfig &cfg,
                       double &lvl,datetime &tOut)
  {
   const int str = MathMax(1,cfg.swingStrength);
   const int maxS = MathMin(hist,fromShift + MathMax(20,cfg.invLookback));
   bool found = false;
   double best = -1.0;
   datetime bestT = 0;
   for(int s = fromShift; s <= maxS; s++)
     {
      if(!PhInv_OkResist(rsi[s],cfg))
         continue;
      if(!PhIsSwingHigh(rsi,s,hist,str))
         continue;
      if(!found || rsi[s] > best)
        {
         found = true;
         best  = rsi[s];
         bestT = times[s];
        }
     }
   if(!found)
      return(false);
   lvl  = best;
   tOut = bestT;
   return(true);
  }

bool PhFindSupportUTurn(const double &rsi[],const datetime &times[],
                        const int fromShift,const int hist,const SPhConfig &cfg,
                        double &lvl,datetime &tOut)
  {
   const int str = MathMax(1,cfg.swingStrength);
   const int maxS = MathMin(hist,fromShift + MathMax(20,cfg.invLookback));
   bool found = false;
   double best = 999.0;
   datetime bestT = 0;
   for(int s = fromShift; s <= maxS; s++)
     {
      if(!PhInv_OkSupport(rsi[s],cfg))
         continue;
      if(!PhIsSwingLow(rsi,s,hist,str))
         continue;
      if(!found || rsi[s] < best)
        {
         found = true;
         best  = rsi[s];
         bestT = times[s];
        }
     }
   if(!found)
      return(false);
   lvl  = best;
   tOut = bestT;
   return(true);
  }

void PhInv_Set(SPhWalk &w,SPhSRList &L,const double lvl,const datetime t0,
               const datetime tNow,const bool isSupport,const SPhConfig &cfg)
  {
   if(isSupport)
     {
      if(!PhInv_OkSupport(lvl,cfg))
         return;
     }
   else
     {
      if(!PhInv_OkResist(lvl,cfg))
         return;
     }

   w.invLevel = lvl;
   w.invTime  = t0;
   w.invOn    = true;
   PhWalkClearInvBreak(w);
   w.invSegIdx = PhSRListAdd(L,t0,tNow,lvl,isSupport);
  }

void PhInv_StartSell(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                     const int shift,const int hist,const SPhConfig &cfg)
  {
   PhWalkClearInv(w);
   double lvl;
   datetime t0;
   if(!PhFindResistUTurn(rsi,times,shift,hist,cfg,lvl,t0))
      return;
   PhInv_Set(w,L,lvl,t0,times[shift],false,cfg);
  }

// BUY: deepest swing LOW clearly <35 in lookback (mirror sell resist)
void PhInv_StartBuy(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                    const int shift,const int hist,const SPhConfig &cfg)
  {
   PhWalkClearInv(w);
   double lvl;
   datetime t0;
   if(!PhFindSupportUTurn(rsi,times,shift,hist,cfg,lvl,t0))
      return;
   PhInv_Set(w,L,lvl,t0,times[shift],true,cfg);
  }

// Only pivots that formed AFTER regime start (no pre-regime ghost INV)
void PhInv_CaptureDuring(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                         const int shift,const int hist,const SPhConfig &cfg)
  {
   if(w.invOn)
      return;

   const int str = MathMax(1,cfg.swingStrength);
   const int piv = shift + str;
   if(piv + str > hist || piv - str < 1)
      return;
   // pivot must be during this regime (newer or equal to enter bar)
   if(w.regimeStartShift > 0 && piv > w.regimeStartShift)
      return;

   const double pv = rsi[piv];
   const datetime pt = times[piv];

   if(w.state == PH_BULLISH)
     {
      if(!PhInv_OkSupport(pv,cfg))
         return;
      if(!PhIsSwingLow(rsi,piv,hist,str))
         return;
      PhInv_Set(w,L,pv,pt,times[shift],true,cfg);
     }
   else if(w.state == PH_BEARISH)
     {
      if(!PhInv_OkResist(pv,cfg))
         return;
      if(!PhIsSwingHigh(rsi,piv,hist,str))
         return;
      // during sell: only set if none from StartSell; prefer higher peak
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
