//+------------------------------------------------------------------+
//|                                          Phase_BuyRegime.mqh     |
//| S&R OFF — BUY via 65 stay/bounce; leave BUY via 35 stay/bounce   |
//+------------------------------------------------------------------+
#ifndef PHASE_BUY_REGIME_MQH
#define PHASE_BUY_REGIME_MQH

#include "Phase_Types.mqh"

void PhBuy_TrackFloor(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
  }

// leave BUY → SELL
bool PhBuy_Process(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   return(PhStay_SellConfirm(w,cfg,v,vOlder));
  }

// NEUTRAL → BUY
bool PhBuy_TryEnter(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   return(PhStay_BuyConfirm(w,cfg,v,vOlder));
  }

#endif
//+------------------------------------------------------------------+
