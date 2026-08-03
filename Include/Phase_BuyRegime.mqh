//+------------------------------------------------------------------+
//|                                          Phase_BuyRegime.mqh     |
//+------------------------------------------------------------------+
#ifndef PHASE_BUY_REGIME_MQH
#define PHASE_BUY_REGIME_MQH

#include "Phase_Types.mqh"

void PhBuy_TrackFloor(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   if(v >= cfg.bullHard - cfg.tol && v <= cfg.bullFloor + 10.0 + cfg.tol)
      w.taggedFloor = true;
   if(w.taggedFloor && v > cfg.bullFloor + cfg.tol && v > vOlder)
     {
      w.floorHolds++;
      w.taggedFloor = false;
     }
   if(v < cfg.bullHard - cfg.tol)
     {
      w.taggedFloor = false;
      w.floorHolds  = 0;
      w.hadBreakout = false;
     }
  }

// true = INV support broken → leave BUY
bool PhBuy_Process(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   const int need = MathMax(1,cfg.confirmBars);
   const double inv = (w.invOn ? w.invLevel : cfg.bullHard);

   if(v >= inv - cfg.tol)
     {
      w.breakInv = 0;
      return(false);
     }

   w.breakInv++;
   return(w.breakInv >= need);
  }

bool PhBuy_TryEnter(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   const int hold = MathMax(1,cfg.holdBars);
   const int need = MathMax(1,cfg.confirmBars);
   const int needFail = MathMax(1,cfg.capFailCount);

   if(v > cfg.bearCap + cfg.tol)
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

   if(v >= cfg.bearCapLo - cfg.tol)
     {
      w.aboveCap = 0;
      if(w.breakoutPending)
        {
         w.pendingHold++;
         if(w.pendingHold >= need)
            return(true);
        }
      return(false);
     }

   if(w.breakoutPending || w.aboveCap > 0)
      w.capFails++;
   PhWalkClearBreakout(w);

   if(w.hadBreakout && w.floorHolds >= needFail && v >= cfg.bullFloor - cfg.tol)
     {
      w.floorHolds = 0;
      return(true);
     }
   return(false);
  }

#endif
//+------------------------------------------------------------------+
