//+------------------------------------------------------------------+
//|                                            Phase_Regime.mqh      |
//| Ignite: one 500-bar walk at start. Then forward-only (no rewrite)|
//+------------------------------------------------------------------+
#ifndef PHASE_REGIME_MQH
#define PHASE_REGIME_MQH

#include "Phase_Types.mqh"
#include "Phase_SR.mqh"
#include "Phase_PriceSR.mqh"
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
   cfg.invGap        = 2.0;   // never stick S&R on/near 20/35/65/80
   cfg.rsiFloor       = 20.0;
   cfg.rsiCeil        = 80.0;
   cfg.invNearSup     = 25.0; // BUY S&R: never above 25 (below 35 zone)
   cfg.invNearRes     = 70.0; // SELL S&R: never below 70 (above 65 zone)
   cfg.confirmBars    = MathMax(1,confirmBars);
   cfg.holdBars      = MathMax(1,holdBars);
   cfg.capFailCount  = MathMax(1,capFailCount);
   cfg.historyBars   = historyBars;
   cfg.swingStrength  = MathMax(1,swingStr);
   cfg.invLookback    = MathMax(80,cfg.historyBars);
   cfg.invRefreshBars = 200; // after S&R: rolling 200, level moves
  }

int PhRegimeLockBars(const SPhConfig &cfg)
  {
   return(MathMax(1,cfg.holdBars + cfg.confirmBars));
  }

void PhEnterBull(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                 const int shift,const int hist,const SPhConfig &cfg,
                 const bool fromBounce)
  {
   w.state            = PH_BULLISH;
   w.hadBreakout      = true;
   w.capFails         = 0;
   w.belowHard        = 0;
   w.barsInRegime     = 0;
   w.regimeStartShift = shift;
   PhWalkClearBreakout(w);
   PhWalkClearInvBreak(w);
   PhWalkClearZoneStay(w);
   if(w.loopStep != 0 && w.loopStep != 1)
      w.loopStep = 2;
   PhInv_StartBuy(w,L,rsi,times,shift,hist,cfg);
   Print("Phase Regime: BUY rsi=",DoubleToString(rsi[shift],2),
         " bounce=",(fromBounce ? "1" : "0"),
         " @ ",TimeToString(times[shift]));
  }

void PhEnterBear(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                 const int shift,const int hist,const SPhConfig &cfg,
                 const bool fromBounce)
  {
   w.state            = PH_BEARISH;
   w.hadBreakout      = false;
   w.floorHolds       = 0;
   w.capFails         = 0;
   w.belowHard        = 0;
   w.barsInRegime     = 0;
   w.regimeStartShift = shift;
   PhWalkClearBreakout(w);
   PhWalkClearInvBreak(w);
   PhWalkClearZoneStay(w);
   if(w.loopStep != 0 && w.loopStep != 1)
      w.loopStep = 2;
   PhInv_StartSell(w,L,rsi,times,shift,hist,cfg);
  }

void PhRegime_FollowSR(SPhWalk &w,SPhSRList &L,const double &rsi[],const datetime &times[],
                       const int shift,const int hist,const SPhConfig &cfg)
  {
   if(w.state != PH_BULLISH && w.state != PH_BEARISH)
      return;
   PhInv_CaptureDuring(w,L,rsi,times,shift,hist,cfg);
   PhInv_Refresh(w,L,rsi,times,shift,hist,cfg);
   PhInv_Follow(w,L,times[shift]);
  }

// One closed bar — leave/enter via zone bounce + PriceSR sharp; 0=regular Div
void PhRegimeStep(SPhWalk &w,SPhSRList &L,SPhPriceSR &psr,
                  const double &rsi[],const datetime &times[],
                  const int shift,const int hist,const SPhConfig &cfg,
                  const bool newBull,const bool newBear,
                  const datetime divT,const double divRsi,
                  ENUM_PH_REGIME &regimes[])
  {
   if(shift < 1 || shift > hist)
      return;

   const double v = rsi[shift];
   const double vOlder = (shift + 1 <= hist ? rsi[shift + 1] : v);
   const int lockBars = PhRegimeLockBars(cfg);

   PhSell_TrackCap(w,cfg,v);
   PhBuy_TrackFloor(w,cfg,v,vOlder);
   PhRegime_FollowSR(w,L,rsi,times,shift,hist,cfg);

   if(w.state == PH_BULLISH)
     {
      w.barsInRegime++;
      bool fromBounce = false;
      if(PhBuy_Process(w,psr,L,cfg,v,vOlder,times[shift],w.barsInRegime > lockBars,
                       newBull,newBear,divT,divRsi,fromBounce))
         PhEnterBear(w,L,rsi,times,shift,hist,cfg,fromBounce);
     }
   else if(w.state == PH_BEARISH)
     {
      w.barsInRegime++;
      bool fromBounce = false;
      if(PhSell_Process(w,psr,L,cfg,v,vOlder,times[shift],w.barsInRegime > lockBars,
                        newBull,newBear,divT,divRsi,fromBounce))
         PhEnterBull(w,L,rsi,times,shift,hist,cfg,true);
     }
   else
     {
      PhStay_LoopDrive(w,psr,L,cfg,v,vOlder,times[shift],newBull,newBear,divT,divRsi);
      if(PhStay_BounceBuyFrom3540(w,cfg,v,vOlder))
         PhEnterBull(w,L,rsi,times,shift,hist,cfg,false);
      else if(PhStay_BounceSellFrom6065(w,cfg,v,vOlder))
         PhEnterBear(w,L,rsi,times,shift,hist,cfg,true);
      else if(v >= 50.0)
        {
         PhWalkClearZoneSell(w);
         if(PhBuy_TryEnter(w,cfg,v,vOlder))
            PhEnterBull(w,L,rsi,times,shift,hist,cfg,false);
        }
      else
        {
         PhWalkClearZoneBuy(w);
         if(PhSell_TryEnter(w,cfg,v,vOlder))
            PhEnterBear(w,L,rsi,times,shift,hist,cfg,false);
        }
     }

   regimes[shift] = w.state;
  }

// EA start only — full history ignite; walk state kept for forward steps
void PhBuildRegimes(const double &rsi[],const datetime &times[],const int hist,
                    const SPhConfig &cfg,ENUM_PH_REGIME &regimes[],
                    SPhSRList &srList,SPhWalk &w,SPhPriceSR &psr)
  {
   PhWalkReset(w);
   PhSRListClear(srList);

   for(int shift = hist; shift >= 1; shift--)
      PhRegimeStep(w,srList,psr,rsi,times,shift,hist,cfg,false,false,0,0.0,regimes);
  }

// New closed bar: slide frozen history, bump enter-shift, step once
void PhRegimeAdvance(SPhWalk &w,SPhSRList &L,SPhPriceSR &psr,
                     const double &rsi[],const datetime &times[],
                     const int hist,const SPhConfig &cfg,
                     const bool newBull,const bool newBear,
                     const datetime divT,const double divRsi,
                     ENUM_PH_REGIME &regimes[])
  {
   const int oldSize = ArraySize(regimes);
   ENUM_PH_REGIME prev[];
   ArrayResize(prev,oldSize);
   for(int i = 0; i < oldSize; i++)
      prev[i] = regimes[i];

   ArrayResize(regimes,hist + 1);
   ArrayInitialize(regimes,(int)PH_NEUTRAL);

   const int copyMax = MathMin(hist - 1,oldSize - 1);
   for(int i = 1; i <= copyMax; i++)
     {
      if(i + 1 <= hist)
         regimes[i + 1] = prev[i];
     }

   if(w.regimeStartShift > 0)
      w.regimeStartShift++;

   PhRegimeStep(w,L,psr,rsi,times,1,hist,cfg,newBull,newBear,divT,divRsi,regimes);
  }

#endif
//+------------------------------------------------------------------+
