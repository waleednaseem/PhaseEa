//+------------------------------------------------------------------+
//|                                                 Phase_SR.mqh     |
//| Dynamic INV: U-turn/bounce <=35 (BUY support) / >=65 (SELL resist)|
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

// Most recent swing HIGH at/above 65 (look from shift toward older)
bool PhFindResistUTurn(const double &rsi[],const datetime &times[],
                       const int fromShift,const int hist,const SPhConfig &cfg,
                       double &lvl,datetime &tOut)
  {
   const int str = MathMax(1,cfg.swingStrength);
   lvl = cfg.bearCap;
   tOut = (fromShift < ArraySize(times) ? times[fromShift] : 0);

   for(int s = fromShift; s <= hist; s++)
     {
      if(rsi[s] < cfg.bearCap - cfg.tol)
         continue;
      // prefer confirmed swing; else local peak vs older neighbor
      bool swing = PhIsSwingHigh(rsi,s,hist,str);
      if(!swing && s + 1 <= hist)
         swing = (rsi[s] >= rsi[s + 1] && (s <= 1 || rsi[s] >= rsi[s - 1]));
      if(!swing)
         continue;
      lvl = rsi[s];
      tOut = times[s];
      return(true);
     }
   return(false);
  }

// Most recent swing LOW at/below 35
bool PhFindSupportUTurn(const double &rsi[],const datetime &times[],
                        const int fromShift,const int hist,const SPhConfig &cfg,
                        double &lvl,datetime &tOut)
  {
   const int str = MathMax(1,cfg.swingStrength);
   lvl = cfg.bullHard;
   tOut = (fromShift < ArraySize(times) ? times[fromShift] : 0);

   for(int s = fromShift; s <= hist; s++)
     {
      if(rsi[s] > cfg.bullHard + cfg.tol)
         continue;
      bool swing = PhIsSwingLow(rsi,s,hist,str);
      if(!swing && s + 1 <= hist)
         swing = (rsi[s] <= rsi[s + 1] && (s <= 1 || rsi[s] <= rsi[s - 1]));
      if(!swing)
         continue;
      lvl = rsi[s];
      tOut = times[s];
      return(true);
     }
   return(false);
  }

void PhInv_StartSell(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                     const int shift,const int hist,const SPhConfig &cfg)
  {
   double lvl;
   datetime t0;
   PhFindResistUTurn(rsi,times,shift,hist,cfg,lvl,t0);
   w.invLevel = lvl;
   w.invTime  = t0;
   w.invOn    = true;
   w.breakInv = 0;
   datetime tNow = times[shift];
   w.invSegIdx = PhSRListAdd(L,t0,tNow,lvl,false); // resist
  }

void PhInv_StartBuy(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                    const int shift,const int hist,const SPhConfig &cfg)
  {
   double lvl;
   datetime t0;
   PhFindSupportUTurn(rsi,times,shift,hist,cfg,lvl,t0);
   w.invLevel = lvl;
   w.invTime  = t0;
   w.invOn    = true;
   w.breakInv = 0;
   datetime tNow = times[shift];
   w.invSegIdx = PhSRListAdd(L,t0,tNow,lvl,true); // support
  }

void PhInv_Follow(SPhWalk &w,SPhSRList &L,const datetime tNow)
  {
   if(!w.invOn || w.invSegIdx < 0)
      return;
   PhSRListExtend(L,w.invSegIdx,tNow);
  }

#endif
//+------------------------------------------------------------------+
