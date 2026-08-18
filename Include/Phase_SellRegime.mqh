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

bool PhSell_Process(SPhWalk &w,SPhPriceSR &psr,const SPhConfig &cfg,
                    const double v,const double vOlder,const datetime barT,
                    const bool canFlip,const bool newRegularDiv,bool &fromBounce)
  {
   fromBounce = false;
   const bool just0 = PhStay_LoopTryMark0(w,newRegularDiv);

   if(PhStay_LoopInvalidate1(w,cfg,v))
      return(false);

   if(w.loopStep == 0 && !just0)
     {
      if(PhStay_BounceSellFrom6065(w,cfg,v,vOlder))
         PhStay_LoopSet1(w,v,vOlder,true,barT);
      else if(PhPriceSR_LoopSharpRejectDown(psr,w,cfg,v,vOlder))
         PhStay_LoopSet1(w,v,vOlder,true,barT);
     }

   if(w.loopStep == 1 && w.loopStep1Time != barT)
     {
      if(PhStay_BounceBuyFrom3540(w,cfg,v,vOlder))
        {
         fromBounce = true;
         w.loopEvt2 = true;
         w.loop50Ready = true;
         return(true);
        }
      if(PhPriceSR_LoopSharpBounceUp(psr,w,cfg,v,vOlder))
        {
         fromBounce = true;
         w.loopEvt2 = true;
         w.loop50Ready = true;
         return(true);
        }
     }

   if(w.loopStep == 2)
     {
      if(PhStay_BounceBuyFrom50(w,cfg,v,vOlder))
        {
         fromBounce = true;
         return(true);
        }
     }

   // Classic 65 confirm — regime flip (latch does not block)
   return(PhStay_BuyConfirm(w,cfg,v,vOlder,canFlip));
  }

bool PhSell_TryEnter(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   return(PhStay_SellConfirm(w,cfg,v,vOlder,true));
  }

#endif
//+------------------------------------------------------------------+
