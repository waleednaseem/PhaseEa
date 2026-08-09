//+------------------------------------------------------------------+
//|                                         Phase_SellRegime.mqh     |
//| Leave SELL: stay above resist S&R (INV) — mirror of Buy leave    |
//+------------------------------------------------------------------+
#ifndef PHASE_SELL_REGIME_MQH
#define PHASE_SELL_REGIME_MQH

#include "Phase_Types.mqh"

void PhSell_TrackCap(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   if(v >= cfg.bearCapLo - cfg.tol)
      w.taggedCap = true;
  }

// leave SELL: stay above INV resist; if no INV → stay >65 only
// Mirror PhBuy_Process (buy: stay below support / 35)
bool PhSell_Process(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
   const int hold = MathMax(1,cfg.holdBars);
   const int need = MathMax(1,cfg.confirmBars);
   w.floorHolds = 0;

   // invOn: resist S&R line only; else bearCap (65)
   const double needLvl = w.invOn
                          ? (w.invLevel + cfg.tol)
                          : (cfg.bearCap + cfg.tol);

   // rejected back at/under INV (or 65) → cancel pending BUY (stay SELL)
   if(v <= needLvl)
     {
      PhWalkClearBreakout(w);
      return(false);
     }

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
