//+------------------------------------------------------------------+
//|                                         Phase_SellRegime.mqh     |
//| S&R OFF — SELL via 35 stay/bounce; leave SELL via 65 stay/bounce |
//+------------------------------------------------------------------+
#ifndef PHASE_SELL_REGIME_MQH
#define PHASE_SELL_REGIME_MQH

#include "Phase_Types.mqh"

void PhSell_TrackCap(SPhWalk &w,const SPhConfig &cfg,const double v)
  {
  }

// leave SELL → BUY
bool PhSell_Process(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder,
                    const bool canFlip)
  {
   return(PhStay_BuyConfirm(w,cfg,v,vOlder,canFlip));
  }

bool PhSell_TryEnter(SPhWalk &w,const SPhConfig &cfg,const double v,const double vOlder)
  {
   return(PhStay_SellConfirm(w,cfg,v,vOlder,true));
  }

#endif
//+------------------------------------------------------------------+
