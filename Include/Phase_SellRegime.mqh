//+------------------------------------------------------------------+
//|                                         Phase_SellRegime.mqh     |
//| SELL leave → BUY: classic 65 + 0-1-2 bounce                      |
//+------------------------------------------------------------------+
#ifndef PHASE_SELL_REGIME_MQH
#define PHASE_SELL_REGIME_MQH

#include "Phase_Types.mqh"
#include "Phase_PriceSR.mqh"

void PhSell_TrackCap(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
  }

bool PhSell_Process(SPhWalk &w,SPhPriceSR &psr,SPhSRList &L,const SPhConfig &cfg,
                    const double v,const double vOlder,const datetime barT,
                    const bool canFlip,const bool newBull,const bool newBear,
                    const datetime divT,const double divRsi,bool &fromBounce)
  {
   fromBounce = false;
   const int want = PhStay_LoopDrive(w,psr,L,cfg,v,vOlder,barT,newBull,newBear,divT,divRsi);
   if(want > 0)
     {
      fromBounce = true;
      return(true);
     }

   // 2 ke baad: 50 bounce UP → BUY (latch ke bawajood)
   if(w.loopLatch || w.loopStep == 2)
     {
      if(PhStay_BounceBuyFrom50(w,cfg,v,vOlder))
        {
         fromBounce = true;
         return(true);
        }
     }

   if(w.loopLatch)
      return(false);

   return(PhStay_BuyConfirm(w,cfg,v,vOlder,canFlip));
  }

bool PhSell_TryEnter(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   return(PhStay_SellConfirm(w,cfg,v,vOlder,true));
  }

#endif
//+------------------------------------------------------------------+
