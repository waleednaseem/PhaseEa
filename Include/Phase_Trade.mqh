//+------------------------------------------------------------------+
//|                                              Phase_Trade.mqh     |
//| Bounce entries + CloseAll / side close (magic-scoped)            |
//| Raw OrderSend — no Trade.mqh dependency                          |
//+------------------------------------------------------------------+
#ifndef PHASE_TRADE_MQH
#define PHASE_TRADE_MQH

#include "Phase_Types.mqh"
#include "Phase_FVG.mqh"

struct SPhTradeCfg
  {
   bool   enable;
   double lot;
   int    slPips;
   int    tpPips;
   long   magic;
   double zoneTol;
   int    deviation;
   int    fvgLookback;
   int    fvgMinGapPts;
   int    fvgMaxPts;
  };

struct SPhTradeState
  {
   bool     armedBuy;      // 35-40 / 50
   bool     armedSell;     // 60-65 / 50
   bool     armedBuyHi;    // bull: 60-65 pullback bounce-up
   bool     armedSellLo;   // bear: 35-40 bounce-down
   bool     sawAbove65;    // bull: RSI was above 65 before pullback
   bool     sawBelow35;    // bear: RSI was below 35 before rally
   bool     seqLocked;     // after SL: no entries until helping HD/Div/FVG
   datetime histFrom;
   // Brown FVG soft reject: arm on touch → fire on reject close
   bool     fvgPending;
   bool     fvgArmFromBelow; // true=upper FVG (from below); false=lower (from above)
   datetime fvgTouchBar;
   datetime fvgLastFireBar;
   datetime fvgLastDetect;
   SPhFvg   fvgZone;
  };

void PhTrade_CfgDefault(SPhTradeCfg &c)
  {
   c.enable       = true;
   c.lot          = 0.01;
   c.slPips       = 800;
   c.tpPips       = 0;
   c.magic        = 140001;
   c.zoneTol      = 0.5;
   c.deviation    = 30;
   c.fvgLookback  = 500;
   c.fvgMinGapPts = 10;
   c.fvgMaxPts    = 1500;
  }

void PhTrade_Init(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   st.armedBuy    = false;
   st.armedSell   = false;
   st.armedBuyHi  = false;
   st.armedSellLo = false;
   st.sawAbove65  = false;
   st.sawBelow35  = false;
   st.seqLocked   = false;
   st.histFrom    = TimeCurrent();
   st.fvgPending       = false;
   st.fvgArmFromBelow  = false;
   st.fvgTouchBar      = 0;
   st.fvgLastFireBar   = 0;
   st.fvgLastDetect    = 0;
   st.fvgZone.valid    = false;
  }

void PhTrade_ResetArms(SPhTradeState &st)
  {
   st.armedBuy    = false;
   st.armedSell   = false;
   st.armedBuyHi  = false;
   st.armedSellLo = false;
   st.sawAbove65  = false;
   st.sawBelow35  = false;
  }

void PhTrade_LockSeq(SPhTradeState &st)
  {
   st.seqLocked = true;
   PhTrade_ResetArms(st);
  }

void PhTrade_UnlockSeq(SPhTradeState &st)
  {
   if(st.seqLocked)
      Print("Phase Trade: sequence UNLOCKED (helping HD/Div/FVG)");
   st.seqLocked = false;
  }

void PhTrade_ClearFvgArm(SPhTradeState &st)
  {
   st.fvgPending = false;
   st.fvgTouchBar = 0;
   st.fvgZone.valid = false;
   st.fvgArmFromBelow = false;
  }

bool PhTrade_Open(SPhTradeState &st,const SPhTradeCfg &cfg,const ENUM_ORDER_TYPE type,
                  const string comment="PH_BNC");

// Soft brown reject → unlock + exactly 1 regime-aligned entry (no CloseAll)
bool PhTrade_FireFvgReject(SPhTradeState &st,const SPhTradeCfg &cfg,
                           const bool isBuy,const datetime barTime)
  {
   if(barTime <= 0)
      return(false);
   if(st.fvgLastFireBar == barTime)
      return(false);
   if(st.fvgZone.valid && st.fvgZone.detectTime > 0 &&
      st.fvgLastDetect == st.fvgZone.detectTime && st.fvgLastFireBar > 0)
      return(false);

   PhTrade_UnlockSeq(st);
   ENUM_ORDER_TYPE typ = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   bool ok = PhTrade_Open(st,cfg,typ,"PH_FVG");
   if(ok)
     {
      st.fvgLastFireBar = barTime;
      if(st.fvgZone.valid)
         st.fvgLastDetect = st.fvgZone.detectTime;
      Print("Phase Trade: ",(isBuy ? "BUY" : "SELL"),
            " on brown FVG reject @ ",TimeToString(barTime),
            " fromBelow=",st.fvgArmFromBelow);
     }
   return(ok);
  }

// Live shift=1: BUY=upper FVG from-below reject-down; SELL=lower from-above reject-up
void PhTrade_CheckFvgReject(SPhTradeState &st,const SPhTradeCfg &cfg,
                            const ENUM_PH_REGIME regime)
  {
   if(!cfg.enable)
      return;
   if(regime != PH_BULLISH && regime != PH_BEARISH)
     {
      PhTrade_ClearFvgArm(st);
      return;
     }

   const int shift = 1;
   datetime barTime = iTime(_Symbol,_Period,shift);
   if(barTime <= 0)
      return;

   const bool isBuy = (regime == PH_BULLISH);

   // --- pending: wait reject close outside ---
   if(st.fvgPending && st.fvgZone.valid &&
      st.fvgTouchBar > 0 && barTime > st.fvgTouchBar)
     {
      if(PhFvg_WasCrossedBeforeShift(_Symbol,_Period,st.fvgZone,shift))
        {
         Print("Phase FVG pending drop — already crossed @ ",TimeToString(barTime));
         PhTrade_ClearFvgArm(st);
         return;
        }

      double o = iOpen(_Symbol,_Period,shift);
      double c = iClose(_Symbol,_Period,shift);
      bool stillInside = (c >= st.fvgZone.gapBottom && c <= st.fvgZone.gapTop);
      if(stillInside)
         return;

      bool thisBarFullUp = (c > st.fvgZone.gapTop && o < st.fvgZone.gapBottom);
      bool thisBarFullDown = (c < st.fvgZone.gapBottom && o > st.fvgZone.gapTop);
      if(thisBarFullUp || thisBarFullDown)
        {
         Print("Phase FVG full-cross — no trade @ ",TimeToString(barTime));
         PhTrade_ClearFvgArm(st);
         return;
        }

      bool upperRejectDown = (c < st.fvgZone.gapBottom);
      bool lowerRejectUp   = (c > st.fvgZone.gapTop);
      bool softOk = (!isBuy && lowerRejectUp && !st.fvgArmFromBelow) ||
                    (isBuy && upperRejectDown && st.fvgArmFromBelow);
      if(softOk)
         PhTrade_FireFvgReject(st,cfg,isBuy,barTime);
      else
         Print("Phase FVG breakout/wrong-side — clear @ ",TimeToString(barTime));

      PhTrade_ClearFvgArm(st);
      return;
     }

   if(st.fvgPending)
      return;

   // --- arm on supporting brown touch ---
   int sideFilter = isBuy ? 2 : 1;
   SPhFvg zone;
   datetime touchTime = 0;
   if(!PhFvg_FindBrownTouchAtShift(_Symbol,_Period,shift,
                                   cfg.fvgLookback,cfg.fvgMinGapPts,sideFilter,
                                   zone,touchTime))
      return;

   double c = iClose(_Symbol,_Period,shift);
   double hi = iHigh(_Symbol,_Period,shift);
   double lo = iLow(_Symbol,_Period,shift);
   if(!PhFvg_BarTouchesZone(hi,lo,zone))
      return;

   double prevClose = iClose(_Symbol,_Period,shift + 1);
   bool fromBelow = (prevClose < zone.gapBottom);
   bool fromAbove = (prevClose > zone.gapTop);
   if(!fromBelow && !fromAbove)
      return;
   if(isBuy && !fromBelow)
      return;
   if(!isBuy && !fromAbove)
      return;

   st.fvgPending = true;
   st.fvgTouchBar = touchTime;
   st.fvgZone = zone;
   st.fvgArmFromBelow = fromBelow;
   Print("Phase FVG arm @ ",TimeToString(touchTime),
         " side=",sideFilter," fromBelow=",fromBelow,
         " — wait reject");

   // Same-bar soft reject (wick in, close out)
   if(PhFvg_WasCrossedBeforeShift(_Symbol,_Period,zone,shift))
      return;

   bool upperRejectDown = (c < zone.gapBottom);
   bool lowerRejectUp   = (c > zone.gapTop);
   bool softOk = (!isBuy && lowerRejectUp && fromAbove) ||
                 (isBuy && upperRejectDown && fromBelow);
   if(!softOk)
      return;

   double o = iOpen(_Symbol,_Period,shift);
   bool thisBarFullUp = (c > zone.gapTop && o < zone.gapBottom);
   bool thisBarFullDown = (c < zone.gapBottom && o > zone.gapTop);
   if(thisBarFullUp || thisBarFullDown)
     {
      PhTrade_ClearFvgArm(st);
      return;
     }

   PhTrade_FireFvgReject(st,cfg,isBuy,barTime);
   PhTrade_ClearFvgArm(st);
  }

bool PhTrade_IsLocked(const SPhTradeState &st)
  {
   return(st.seqLocked);
  }

double PhTrade_PipSize()
  {
   if(_Digits == 3 || _Digits == 5)
      return(10.0 * _Point);
   return(_Point);
  }

int PhTrade_PipsToPoints(const int pips)
  {
   double pip = PhTrade_PipSize();
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   return((int)MathRound((double)pips * pip / point));
  }

double PhTrade_NormalizeLot(const double lot)
  {
   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step <= 0.0) step = 0.01;
   double v = MathFloor(lot / step + 1e-12) * step;
   if(v < vmin) v = vmin;
   if(v > vmax) v = vmax;
   return(NormalizeDouble(v,2));
  }

ENUM_ORDER_TYPE_FILLING PhTrade_Filling()
  {
   long modes = SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((modes & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return(ORDER_FILLING_FOK);
   if((modes & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return(ORDER_FILLING_IOC);
   return(ORDER_FILLING_RETURN);
  }

bool PhTrade_InBuyZone(const double rsi,const double tol)
  {
   if(rsi >= 35.0 && rsi <= 40.0)
      return(true);
   if(MathAbs(rsi - 50.0) <= tol)
      return(true);
   return(false);
  }

bool PhTrade_InSellZone(const double rsi,const double tol)
  {
   if(rsi >= 60.0 && rsi <= 65.0)
      return(true);
   if(MathAbs(rsi - 50.0) <= tol)
      return(true);
   return(false);
  }

bool PhTrade_InZone6065(const double rsi)
  {
   return(rsi >= 60.0 && rsi <= 65.0);
  }

bool PhTrade_InZone3540(const double rsi)
  {
   return(rsi >= 35.0 && rsi <= 40.0);
  }

bool PhTrade_IsOurs(const ulong ticket,const long magic)
  {
   if(!PositionSelectByTicket(ticket))
      return(false);
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return(false);
   if(PositionGetInteger(POSITION_MAGIC) != magic)
      return(false);
   return(true);
  }

bool PhTrade_Send(MqlTradeRequest &req,MqlTradeResult &res)
  {
   ResetLastError();
   if(!OrderSend(req,res))
     {
      Print("Phase Trade: OrderSend fail err=",GetLastError(),
            " ret=",res.retcode," ",res.comment);
      return(false);
     }
   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED
      && res.retcode != TRADE_RETCODE_DONE_PARTIAL)
     {
      Print("Phase Trade: retcode=",res.retcode," ",res.comment);
      return(false);
     }
   return(true);
  }

double PhTrade_CalcSl(const SPhTradeCfg &cfg,const bool isSell,const double entry)
  {
   double pip = PhTrade_PipSize();
   int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const int minPips = MathMax(800,cfg.slPips);
   int minPts = PhTrade_PipsToPoints(minPips);
   int maxPts = MathMax(cfg.fvgMaxPts,minPts);

   double fvgSl = 0.0;
   if(PhFvg_FindSecondSl(_Symbol,_Period,isSell,entry,
                         cfg.fvgLookback,cfg.fvgMinGapPts,maxPts,fvgSl,minPts))
     {
      // Hard floor: FVG SL must be ≥ minPips (never tighter than 800)
      double distPips = MathAbs(fvgSl - entry) / pip;
      if(distPips + 1e-9 >= (double)minPips)
         return(fvgSl);
      Print("Phase FVG-SL reject dist=",DoubleToString(distPips,1),
            " pips < ",minPips," → min-pips fallback");
     }

   if(isSell)
      return(NormalizeDouble(entry + minPips * pip,digits));
   return(NormalizeDouble(entry - minPips * pip,digits));
  }

bool PhTrade_Open(SPhTradeState &st,const SPhTradeCfg &cfg,const ENUM_ORDER_TYPE type,
                  const string comment="PH_BNC")
  {
   if(!cfg.enable)
      return(false);
   if(st.seqLocked)
      return(false);

   double lot = PhTrade_NormalizeLot(cfg.lot);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.deviation = cfg.deviation;
   req.magic     = cfg.magic;
   req.comment   = comment;
   req.type_filling = PhTrade_Filling();

   if(type == ORDER_TYPE_BUY)
     {
      req.type  = ORDER_TYPE_BUY;
      req.price = ask;
      req.sl    = PhTrade_CalcSl(cfg,false,ask);
      req.tp    = 0.0;
     }
   else if(type == ORDER_TYPE_SELL)
     {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
      req.sl    = PhTrade_CalcSl(cfg,true,bid);
      req.tp    = 0.0;
     }
   else
      return(false);

   return(PhTrade_Send(req,res));
  }

bool PhTrade_CloseTicket(const ulong ticket,const SPhTradeCfg &cfg)
  {
   if(!PositionSelectByTicket(ticket))
      return(false);

   double vol = PositionGetDouble(POSITION_VOLUME);
   long   typ = PositionGetInteger(POSITION_TYPE);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action    = TRADE_ACTION_DEAL;
   req.position  = ticket;
   req.symbol    = _Symbol;
   req.volume    = vol;
   req.deviation = cfg.deviation;
   req.magic     = cfg.magic;
   req.comment   = "PH_CLS";
   req.type_filling = PhTrade_Filling();

   if(typ == POSITION_TYPE_BUY)
     {
      req.type  = ORDER_TYPE_SELL;
      req.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
     }
   else
     {
      req.type  = ORDER_TYPE_BUY;
      req.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
     }

   return(PhTrade_Send(req,res));
  }

int PhTrade_CloseAll(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   if(!cfg.enable)
      return(0);
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PhTrade_IsOurs(ticket,cfg.magic))
         continue;
      if(PhTrade_CloseTicket(ticket,cfg))
         closed++;
      else
         Print("Phase Trade: CloseAll fail ticket=",ticket," err=",GetLastError());
     }
   return(closed);
  }

int PhTrade_CloseByType(SPhTradeState &st,const SPhTradeCfg &cfg,const ENUM_POSITION_TYPE ptype)
  {
   if(!cfg.enable)
      return(0);
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PhTrade_IsOurs(ticket,cfg.magic))
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != ptype)
         continue;
      if(PhTrade_CloseTicket(ticket,cfg))
         closed++;
      else
         Print("Phase Trade: CloseByType fail ticket=",ticket," err=",GetLastError());
     }
   return(closed);
  }

bool PhTrade_PollSlLock(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   if(!cfg.enable)
      return(false);

   datetime now = TimeCurrent();
   datetime from = st.histFrom;
   if(from <= 0)
      from = now;
   if(!HistorySelect(from,now + 1))
      return(false);

   bool slHit = false;
   datetime latest = from;
   const int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      datetime dt = (datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
      if(dt <= from)
         continue;
      if(dt > latest)
         latest = dt;
      if(HistoryDealGetString(ticket,DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(ticket,DEAL_MAGIC) != cfg.magic)
         continue;
      long entry = HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      long reason = HistoryDealGetInteger(ticket,DEAL_REASON);
      if(reason == DEAL_REASON_SL)
         slHit = true;
     }

   st.histFrom = (latest > from ? latest : now);

   if(!slHit)
      return(false);

   int nClose = PhTrade_CloseAll(st,cfg);
   PhTrade_LockSeq(st);
   Print("Phase Trade: SL hit → CloseAll n=",nClose," SEQUENCE LOCKED (wait HD/Div)");
   return(true);
  }

void PhTrade_CheckBounce(SPhTradeState &st,const SPhTradeCfg &cfg,
                         const ENUM_PH_REGIME regime,const double &rsi[])
  {
   if(!cfg.enable)
      return;
   if(st.seqLocked)
     {
      PhTrade_ResetArms(st);
      return;
     }
   if(ArraySize(rsi) < 3)
      return;

   const double r1 = rsi[1];
   const double r2 = rsi[2];

   if(regime == PH_BULLISH)
     {
      st.armedSell = false;
      st.armedSellLo = false;
      st.sawBelow35 = false;

      if(r1 > 65.0)
         st.sawAbove65 = true;
      // crossed down into 60-65 from above
      if(st.sawAbove65 && PhTrade_InZone6065(r1))
         st.armedBuyHi = true;
      if(r1 < 60.0)
        {
         st.armedBuyHi = false;
         // stayed below 60 — need fresh pullback from >65
         if(r1 < 55.0)
            st.sawAbove65 = false;
        }

      bool fired = false;
      // Hi-zone bounce: still >=60, RSI up
      if(st.armedBuyHi && r1 >= 60.0 && r1 > r2)
        {
         if(PhTrade_Open(st,cfg,ORDER_TYPE_BUY,"PH_BNC"))
            Print("Phase Trade: BUY 60-65 bounce rsi=",DoubleToString(r1,2));
         st.armedBuyHi = false;
         st.sawAbove65 = false;
         fired = true;
        }
      // Classic low/50 bounce
      if(!fired && st.armedBuy && r1 > r2)
        {
         if(PhTrade_Open(st,cfg,ORDER_TYPE_BUY))
            Print("Phase Trade: BUY bounce rsi=",DoubleToString(r1,2));
         st.armedBuy = false;
         fired = true;
        }
      if(!fired)
        {
         if(PhTrade_InBuyZone(r1,cfg.zoneTol))
            st.armedBuy = true;
         else
            st.armedBuy = false;
        }
      else if(PhTrade_InBuyZone(r1,cfg.zoneTol))
         st.armedBuy = true;
     }
   else if(regime == PH_BEARISH)
     {
      st.armedBuy = false;
      st.armedBuyHi = false;
      st.sawAbove65 = false;
      st.sawBelow35 = false;

      if(PhTrade_InZone3540(r1))
         st.armedSellLo = true;
      else if(r1 > 40.0)
         st.armedSellLo = false;

      bool fired = false;
      // Lo-zone bounce down: still <=40, RSI down
      if(st.armedSellLo && r1 <= 40.0 && r1 < r2)
        {
         if(PhTrade_Open(st,cfg,ORDER_TYPE_SELL,"PH_BNC"))
            Print("Phase Trade: SELL 35-40 bounce rsi=",DoubleToString(r1,2));
         st.armedSellLo = false;
         fired = true;
        }
      if(!fired && st.armedSell && r1 < r2)
        {
         if(PhTrade_Open(st,cfg,ORDER_TYPE_SELL))
            Print("Phase Trade: SELL bounce rsi=",DoubleToString(r1,2));
         st.armedSell = false;
         fired = true;
        }
      if(!fired)
        {
         if(PhTrade_InSellZone(r1,cfg.zoneTol))
            st.armedSell = true;
         else
            st.armedSell = false;
        }
      else if(PhTrade_InSellZone(r1,cfg.zoneTol))
         st.armedSell = true;
     }
   else
      PhTrade_ResetArms(st);
  }

#endif
//+------------------------------------------------------------------+
