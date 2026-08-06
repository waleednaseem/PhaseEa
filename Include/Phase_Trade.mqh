//+------------------------------------------------------------------+
//|                                              Phase_Trade.mqh     |
//| Bounce entries + CloseAll / side close (magic-scoped)            |
//| Raw OrderSend — no Trade.mqh dependency                          |
//+------------------------------------------------------------------+
#ifndef PHASE_TRADE_MQH
#define PHASE_TRADE_MQH

#include "Phase_Types.mqh"

struct SPhTradeCfg
  {
   bool   enable;
   double lot;
   int    slPips;
   int    tpPips;
   long   magic;
   double zoneTol;
   int    deviation;
  };

struct SPhTradeState
  {
   bool     armedBuy;
   bool     armedSell;
   bool     seqLocked;     // after SL: no entries until helping HD
   datetime histFrom;      // deal scan cursor
  };

void PhTrade_CfgDefault(SPhTradeCfg &c)
  {
   c.enable    = true;
   c.lot       = 0.01;
   c.slPips    = 800;
   c.tpPips    = 0;     // no fixed TP
   c.magic     = 140001;
   c.zoneTol   = 0.5;
   c.deviation = 30;
  }

void PhTrade_Init(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   st.armedBuy   = false;
   st.armedSell  = false;
   st.seqLocked  = false;
   st.histFrom   = TimeCurrent();
  }

void PhTrade_ResetArms(SPhTradeState &st)
  {
   st.armedBuy  = false;
   st.armedSell = false;
  }

void PhTrade_LockSeq(SPhTradeState &st)
  {
   st.seqLocked = true;
   PhTrade_ResetArms(st);
  }

void PhTrade_UnlockSeq(SPhTradeState &st)
  {
   if(st.seqLocked)
      Print("Phase Trade: sequence UNLOCKED (helping HD)");
   st.seqLocked = false;
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

bool PhTrade_Open(SPhTradeState &st,const SPhTradeCfg &cfg,const ENUM_ORDER_TYPE type,
                  const string comment="PH_BNC")
  {
   if(!cfg.enable)
      return(false);
   if(st.seqLocked)
      return(false);

   double lot = PhTrade_NormalizeLot(cfg.lot);
   double pip = PhTrade_PipSize();
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

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
      req.sl    = NormalizeDouble(ask - MathMax(800,cfg.slPips) * pip,digits);
      req.tp    = 0.0;   // dynamic / Div close — no fixed TP
     }
   else if(type == ORDER_TYPE_SELL)
     {
      req.type  = ORDER_TYPE_SELL;
      req.price = bid;
      req.sl    = NormalizeDouble(bid + MathMax(800,cfg.slPips) * pip,digits);
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

// Any Phase SL deal → CloseAll remaining + lock sequence until helping HD
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
   Print("Phase Trade: SL hit → CloseAll n=",nClose," SEQUENCE LOCKED (wait helping HD)");
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
      bool fired = false;
      if(st.armedBuy && r1 > r2)
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
      bool fired = false;
      if(st.armedSell && r1 < r2)
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
