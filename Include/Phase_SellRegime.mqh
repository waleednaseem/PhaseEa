//+------------------------------------------------------------------+
//|                                         Phase_SellRegime.mqh     |
//| Leave SELL only: cross INV + STAY above 65 (failed spike cancels)|
//+------------------------------------------------------------------+
#ifndef PHASE_SELL_REGIME_MQH
#define PHASE_SELL_REGIME_MQH

#include "Phase_Types.mqh"

void PhSell_TrackCap(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   if(v >= cfg.bearCapLo - cfg.tol)
      w.taggedCap = true;
  }

// true only if INV crossed AND stayed above bearCap (65) — no flicker BUY
bool PhSell_Process(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   const int hold = MathMax(1,cfg.holdBars);
   const int need = MathMax(1,cfg.confirmBars);
   w.floorHolds = 0;

   if(!w.invOn)
     {
      PhWalkClearBreakout(w);
      return(false);
     }

   const double inv = w.invLevel;
   // must clear INV and hold in/above the 65 zone — spike-reject stays SELL
   const double needLvl = MathMax(inv,cfg.bearCap) + cfg.tol;

   if(v > needLvl)
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

   // rejected back under 65 / INV → cancel pending BUY (stay SELL)
   PhWalkClearBreakout(w);
   return(false);
  }

bool PhSell_TryEnter(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   const int hold = MathMax(1,cfg.holdBars);
   const int need = MathMax(1,cfg.confirmBars);
   const int needFail = MathMax(1,cfg.capFailCount);

   if(v < cfg.bullHard - cfg.tol)
     {
      w.belowHard++;
      PhWalkClearBreakout(w);
      if(w.belowHard >= hold)
        {
         w.invBreakPending = true;
         w.invHold++;
         if(w.invHold >= need)
            return(true);
        }
      return(false);
     }

   w.belowHard = 0;
   w.invHold = 0;
   w.invBreakPending = false;

   // cap-fails only count while still below the 65 zone (no mid-range flicker SELL)
   if(w.capFails >= needFail && v < cfg.bearCapLo - cfg.tol)
      return(true);
   return(false);
  }

#endif
//+------------------------------------------------------------------+
