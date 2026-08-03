//+------------------------------------------------------------------+
//|                                            Phase_Regime.mqh      |
//+------------------------------------------------------------------+
#ifndef PHASE_REGIME_MQH
#define PHASE_REGIME_MQH

#include "Phase_Types.mqh"
#include "Phase_SR.mqh"
#include "Phase_BuyRegime.mqh"
#include "Phase_SellRegime.mqh"

void PhConfigLoad(SPhConfig &cfg,
                  const double bullFloor,const double bullHard,
                  const double bearCapLo,const double bearCap,
                  const double tol,const int confirmBars,const int holdBars,
                  const int capFailCount,const int historyBars,const int swingStr)
  {
   cfg.bullFloor     = bullFloor;
   cfg.bullHard      = bullHard;
   cfg.bearCapLo     = bearCapLo;
   cfg.bearCap       = bearCap;
   cfg.tol           = tol;
   cfg.invGap        = 2.0;   // never stick S&R on/near 35 or 65
   cfg.confirmBars   = MathMax(1,confirmBars);
   cfg.holdBars      = MathMax(1,holdBars);
   cfg.capFailCount  = MathMax(1,capFailCount);
   cfg.historyBars   = historyBars;
   cfg.swingStrength = MathMax(1,swingStr);
   cfg.invLookback   = 80;
  }

int PhRegimeLockBars(const SPhConfig &cfg)
  {
   return(MathMax(1,cfg.holdBars + cfg.confirmBars));
  }

void PhEnterBull(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                 const int shift,const int hist,const SPhConfig &cfg)
  {
   w.state            = PH_BULLISH;
   w.hadBreakout      = true;
   w.capFails         = 0;
   w.belowHard        = 0;
   w.barsInRegime     = 0;
   w.regimeStartShift = shift;
   PhWalkClearBreakout(w);
   PhInv_StartBuy(w,L,rsi,times,shift,hist,cfg);
  }

void PhEnterBear(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                 const int shift,const int hist,const SPhConfig &cfg)
  {
   w.state            = PH_BEARISH;
   w.hadBreakout      = false;
   w.floorHolds       = 0;
   w.capFails         = 0;
   w.belowHard        = 0;
   w.barsInRegime     = 0;
   w.regimeStartShift = shift;
   PhWalkClearBreakout(w);
   PhInv_StartSell(w,L,rsi,times,shift,hist,cfg);
  }

void PhBuildRegimes(const double &rsi[],const datetime &times[],const int hist,
                    const SPhConfig &cfg,ENUM_PH_REGIME &regimes[],SPhSRList &srList)
  {
   SPhWalk w;
   PhWalkReset(w);
   PhSRListClear(srList);
   const int lockBars = PhRegimeLockBars(cfg);

   for(int shift = hist; shift >= 1; shift--)
     {
      const double v = rsi[shift];
      const double vOlder = (shift + 1 <= hist ? rsi[shift + 1] : v);
      const datetime t = times[shift];

      PhSell_TrackCap(w,cfg,v);
      PhBuy_TrackFloor(w,cfg,v,vOlder);

      if(w.state == PH_BULLISH)
        {
         w.barsInRegime++;
         PhInv_CaptureDuring(w,srList,rsi,times,shift,hist,cfg);
         PhInv_Follow(w,srList,t);
         if(w.barsInRegime > lockBars && PhBuy_Process(w,cfg,v))
            PhEnterBear(w,srList,rsi,times,shift,hist,cfg);
        }
      else if(w.state == PH_BEARISH)
        {
         w.barsInRegime++;
         PhInv_CaptureDuring(w,srList,rsi,times,shift,hist,cfg);
         PhInv_Follow(w,srList,t);
         if(w.barsInRegime > lockBars && PhSell_Process(w,cfg,v))
            PhEnterBull(w,srList,rsi,times,shift,hist,cfg);
        }
      else
        {
         if(PhBuy_TryEnter(w,cfg,v))
            PhEnterBull(w,srList,rsi,times,shift,hist,cfg);
         else if(PhSell_TryEnter(w,cfg,v))
            PhEnterBear(w,srList,rsi,times,shift,hist,cfg);
        }

      regimes[shift] = w.state;
     }
  }

#endif
//+------------------------------------------------------------------+
