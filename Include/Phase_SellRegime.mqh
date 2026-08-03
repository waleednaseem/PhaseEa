//+------------------------------------------------------------------+
//|                                         Phase_SellRegime.mqh     |
//+------------------------------------------------------------------+
#ifndef PHASE_SELL_REGIME_MQH
#define PHASE_SELL_REGIME_MQH

#include "Phase_Types.mqh"

void PhSell_TrackCap(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   if(v >= cfg.bearCapLo - cfg.tol)
      w.taggedCap = true;
  }

// true = INV resist broken+held → leave SELL
bool PhSell_Process(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   const int hold = MathMax(1,cfg.holdBars);
   const int need = MathMax(1,cfg.confirmBars);
   const double inv = (w.invOn ? w.invLevel : cfg.bearCap);

   w.floorHolds = 0;

   if(v > inv + cfg.tol)
     {
      w.aboveCap++;
      if(w.aboveCap >= hold)
         w.breakoutPending = true;
      if(w.breakoutPending)
        {
         w.pendingHold++;
         if(w.pendingHold >= need)
            return(true);
        }
      return(false);
     }

   if(v < cfg.bearCapLo - cfg.tol)
     {
      if(w.breakoutPending || w.aboveCap > 0 || w.taggedCap)
         w.capFails++;
      w.taggedCap = false;
      PhWalkClearBreakout(w);
     }
   else
      w.aboveCap = 0;

   return(false);
  }

bool PhSell_TryEnter(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   const int need     = MathMax(1,cfg.confirmBars);
   const int needFail = MathMax(1,cfg.capFailCount);

   if(v < cfg.bullHard - cfg.tol)
     {
      w.belowHard++;
      PhWalkClearBreakout(w);
      if(w.belowHard >= need)
         return(true);
      return(false);
     }

   w.belowHard = 0;
   if(w.capFails >= needFail)
      return(true);
   return(false);
  }

#endif
//+------------------------------------------------------------------+
