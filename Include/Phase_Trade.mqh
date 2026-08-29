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
   double bookBaseBal;        // unused
   double bookProfitPct;      // CloseAll when float ≥ this % of initEq
   double dailyProfitPct;     // +% of initEq → stop (0=off / unlimited)
   double dailyLossPct;       // -% of initEq → CloseAll + day stop
   double initDeposit;        // 0=auto-freeze first equity
   double trailLossPct;       // open basket float ≤ −% of initEq → CloseAll
   int    maxOpen;            // max concurrent positions (magic)
   bool   maGate;             // Master Avg: BUY white>red / SELL white<red
  };

struct SPhTradeState
  {
   bool     armedBuy;      // 35-40 / 50
   bool     armedSell;     // 60-65 / 50
   bool     armedBuyHi;    // bull: 60-65 pullback bounce-up
   bool     armedSellLo;   // bear: 35-40 bounce-down
   bool     sawAbove65;    // bull: RSI was above 65 before pullback
   bool     sawBelow35;    // bear: RSI was below 35 before rally
   bool     seqLocked;     // DISABLED — always unlocked
   bool     bosExitPending;// against Div+BOS: wait FVG/bounce rescue before CloseAll
   int      bosExitBars;   // bars since against BOS arm
   bool     realignArmed;   // DISABLED (legacy)
   datetime histFrom;
   // Brown FVG soft reject: arm on touch → fire on reject close
   bool     fvgPending;
   bool     fvgArmFromBelow; // true=upper FVG (from below); false=lower (from above)
   datetime fvgTouchBar;
   datetime fvgLastFireBar;
   datetime fvgLastDetect;
   SPhFvg   fvgZone;
   datetime dayStamp;    // server day 00:00
   double   dayStartEq;  // equity at day start (log only)
   double   runStartEq;  // first day equity (log only)
   double   initEq;      // frozen initial deposit (all risk % base)
   bool     dayStopped;  // daily target hit — no trades until next day
  };

#define PH_BOS_EXIT_WAIT_BARS 5
#define PH_SEQ_MARK_TAG     "PH_Seq"

int    g_phTradeMarkRsiWin = -1;
double g_phTradeMarkRsi    = 0.0;

void PhTrade_SetMarkContext(const int rsiWindow,const double rsi1)
  {
   g_phTradeMarkRsiWin = rsiWindow;
   g_phTradeMarkRsi    = rsi1;
  }

void PhTrade_PaintSeqRect(const string name,const int subwindow,
                          const datetime t1,const double top,
                          const datetime t2,const double bottom,
                          const color clr)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE,subwindow,t1,top,t2,bottom);
   else
     {
      ObjectMove(0,name,0,t1,top);
      ObjectMove(0,name,1,t2,bottom);
     }
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

// LOCK/UNLOCK marks — DISABLED
void PhTrade_PaintSeqMark(const bool isLock)
  {
   // no-op: sequence lock/unlock removed
  }

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
   c.bookBaseBal    = 0.0;
   c.bookProfitPct  = 5.0;
   c.dailyProfitPct = 0.0;   // unlimited by default
   c.dailyLossPct   = 4.8;
   c.initDeposit    = 0.0;
   c.trailLossPct   = 5.0;
   c.maxOpen        = 3;
   c.maGate         = true;
  }

int g_phMaFastH = INVALID_HANDLE; // SMA 10 white
int g_phMaSlowH = INVALID_HANDLE; // SMA 100 red

// #region agent log
void PhDbg_Log(const string hypothesisId,const string location,
               const string message,const string dataJson)
  {
   int h = FileOpen("debug-c5dd7a.log",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|
                    FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      h = FileOpen("debug-c5dd7a.log",FILE_WRITE|FILE_TXT|FILE_ANSI|
                   FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      return;
   FileSeek(h,0,SEEK_END);
   string line = StringFormat(
      "{\"sessionId\":\"c5dd7a\",\"hypothesisId\":\"%s\",\"location\":\"%s\","
      "\"message\":\"%s\",\"data\":%s,\"timestamp\":%I64d}\n",
      hypothesisId,location,message,dataJson,(long)TimeCurrent()*1000);
   FileWriteString(h,line);
   FileClose(h);
  }

bool PhTrade_MaSnapshot(double &fastOut,double &slowOut)
  {
   fastOut = 0.0;
   slowOut = 0.0;
   if(g_phMaFastH == INVALID_HANDLE || g_phMaSlowH == INVALID_HANDLE)
      return(false);
   double fast[1],slow[1];
   if(CopyBuffer(g_phMaFastH,0,1,1,fast) != 1)
      return(false);
   if(CopyBuffer(g_phMaSlowH,0,1,1,slow) != 1)
      return(false);
   fastOut = fast[0];
   slowOut = slow[0];
   return(true);
  }
// #endregion

bool PhTrade_InitMa()
  {
   if(g_phMaFastH != INVALID_HANDLE)
      IndicatorRelease(g_phMaFastH);
   if(g_phMaSlowH != INVALID_HANDLE)
      IndicatorRelease(g_phMaSlowH);
   g_phMaFastH = iMA(_Symbol,_Period,10,0,MODE_SMA,PRICE_CLOSE);
   g_phMaSlowH = iMA(_Symbol,_Period,100,0,MODE_SMA,PRICE_CLOSE);
   if(g_phMaFastH == INVALID_HANDLE || g_phMaSlowH == INVALID_HANDLE)
     {
      Print("Phase Trade: iMA Master Avg failed");
      return(false);
     }
   return(true);
  }

void PhTrade_ReleaseMa()
  {
   if(g_phMaFastH != INVALID_HANDLE)
     {
      IndicatorRelease(g_phMaFastH);
      g_phMaFastH = INVALID_HANDLE;
     }
   if(g_phMaSlowH != INVALID_HANDLE)
     {
      IndicatorRelease(g_phMaSlowH);
      g_phMaSlowH = INVALID_HANDLE;
     }
  }

// white(10) vs red(100) — bar 1; fail-closed if no data
bool PhTrade_MaAllows(const SPhTradeCfg &cfg,const ENUM_ORDER_TYPE type)
  {
   if(!cfg.maGate)
      return(true);
   if(g_phMaFastH == INVALID_HANDLE || g_phMaSlowH == INVALID_HANDLE)
      return(false);

   double fast[1], slow[1];
   if(CopyBuffer(g_phMaFastH,0,1,1,fast) != 1)
      return(false);
   if(CopyBuffer(g_phMaSlowH,0,1,1,slow) != 1)
      return(false);

   if(type == ORDER_TYPE_BUY)
      return(fast[0] > slow[0]);   // white above red
   if(type == ORDER_TYPE_SELL)
      return(fast[0] < slow[0]);   // white below red
   return(false);
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
   st.bosExitPending = false;
   st.bosExitBars = 0;
   st.realignArmed = false;
   st.histFrom    = TimeCurrent();
   st.fvgPending       = false;
   st.fvgArmFromBelow  = false;
   st.fvgTouchBar      = 0;
   st.fvgLastFireBar   = 0;
   st.fvgLastDetect    = 0;
   st.fvgZone.valid    = false;
   st.dayStamp   = 0;
   st.dayStartEq = 0.0;
   st.runStartEq = 0.0;
   st.initEq     = 0.0;
   st.dayStopped = false;
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

void PhTrade_ClearAgainstLock(SPhTradeState &st)
  {
   st.bosExitPending = false;
   st.bosExitBars    = 0;
   st.realignArmed   = false;
  }

void PhTrade_LockSeq(SPhTradeState &st)
  {
   // DISABLED — no sequence lock
   st.seqLocked = false;
   PhTrade_ClearAgainstLock(st);
  }

// Against Div+BOS lock — OFF
void PhTrade_LockAgainstDiv(SPhTradeState &st)
  {
   PhTrade_ClearAgainstLock(st);
  }

void PhTrade_UnlockSeq(SPhTradeState &st)
  {
   // DISABLED — no sequence unlock marks
   st.seqLocked = false;
   PhTrade_ClearAgainstLock(st);
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
bool PhTrade_IsOurs(const ulong ticket,const long magic);
int  PhTrade_CloseAllSoft(SPhTradeState &st,const SPhTradeCfg &cfg,const string why);
double PhTrade_BasketFloat(const long magic);

int PhTrade_CountOurs(const long magic)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PhTrade_IsOurs(ticket,magic))
         continue;
      n++;
     }
   return(n);
  }

// Soft brown reject entry (no opens): 1× PH_FVG
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
   if(PhTrade_CountOurs(cfg.magic) > 0)
      return(false); // open basket: FVG pe CloseAll nahi (survive regime)

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

// Live shift=1: no opens → soft reject → PH_FVG entry
// opens → FVG pe CloseAll nahi (CloseAllSoft gate alag: loss mein skip)
void PhTrade_CheckFvgReject(SPhTradeState &st,const SPhTradeCfg &cfg,
                            const ENUM_PH_REGIME regime)
  {
   if(!cfg.enable)
      return;

   const int shift = 1;
   datetime barTime = iTime(_Symbol,_Period,shift);
   if(barTime <= 0)
      return;

   // open positions: do not book/close on FVG — let regime/Div/SL manage
   if(PhTrade_CountOurs(cfg.magic) > 0)
     {
      PhTrade_ClearFvgArm(st);
      return;
     }

   if(regime != PH_BULLISH && regime != PH_BEARISH)
     {
      PhTrade_ClearFvgArm(st);
      return;
     }

   const bool isBuy = (regime == PH_BULLISH);

   // --- pending: wait reject close outside (entry / unlock path) ---
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

   // --- arm on supporting brown touch (no opens → entry path) ---
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
   return(false); // sequence lock DISABLED
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

// Regime-continue bounce / U-turn on closed bar (shift=1 RSI)
bool PhTrade_HasBounceUturn(const bool isBuy,const double &rsi[])
  {
   if(ArraySize(rsi) < 3)
      return(false);
   const double r1 = rsi[1];
   const double r2 = rsi[2];
   if(isBuy)
      return((PhTrade_InZone3540(r1) && r1 > r2) ||
             (PhTrade_InZone6065(r1) && r1 > r2));
   return((PhTrade_InZone6065(r1) && r1 < r2) ||
          (PhTrade_InZone3540(r1) && r1 < r2));
  }

// Soft FVG reject that rescues after against-BOS:
// BUY → lower FVG from-above reject-up | SELL → upper from-below reject-down
bool PhTrade_HasFvgRescueReject(const SPhTradeCfg &cfg,const bool isBuy)
  {
   const int shift = 1;
   datetime barTime = iTime(_Symbol,_Period,shift);
   if(barTime <= 0)
      return(false);

   const int sideFilter = isBuy ? 1 : 2;
   SPhFvg zone;
   datetime touchTime = 0;
   if(!PhFvg_FindBrownTouchAtShift(_Symbol,_Period,shift,
                                   cfg.fvgLookback,cfg.fvgMinGapPts,sideFilter,
                                   zone,touchTime))
      return(false);

   double c = iClose(_Symbol,_Period,shift);
   double o = iOpen(_Symbol,_Period,shift);
   double hi = iHigh(_Symbol,_Period,shift);
   double lo = iLow(_Symbol,_Period,shift);
   if(!PhFvg_BarTouchesZone(hi,lo,zone) &&
      !(c < zone.gapBottom || c > zone.gapTop))
      return(false);

   double prevClose = iClose(_Symbol,_Period,shift + 1);
   bool fromBelow = (prevClose < zone.gapBottom);
   bool fromAbove = (prevClose > zone.gapTop);
   // same-bar reject OR close already outside after touch this/prev
   bool upperRejectDown = (c < zone.gapBottom);
   bool lowerRejectUp   = (c > zone.gapTop);
   bool softOk = (isBuy && lowerRejectUp && (fromAbove || PhFvg_BarTouchesZone(hi,lo,zone))) ||
                 (!isBuy && upperRejectDown && (fromBelow || PhFvg_BarTouchesZone(hi,lo,zone)));
   if(!softOk)
      return(false);

   bool thisBarFullUp = (c > zone.gapTop && o < zone.gapBottom);
   bool thisBarFullDown = (c < zone.gapBottom && o > zone.gapTop);
   if(thisBarFullUp || thisBarFullDown)
      return(false);
   if(PhFvg_WasCrossedBeforeShift(_Symbol,_Period,zone,shift))
      return(false);
   return(true);
  }

bool PhTrade_AgainstBosRescued(const SPhTradeCfg &cfg,const bool isBuy,
                               const double &rsi[])
  {
   if(PhTrade_HasBounceUturn(isBuy,rsi))
      return(true);
   if(PhTrade_HasFvgRescueReject(cfg,isBuy))
      return(true);
   return(false);
  }

// Opposite Div / against Div+BOS → NEVER cut trades (continue).
// Rescue wait removed — BOS spike pe cut nahi; regime/SL/stack alag handle.
void PhTrade_PollAgainstBosExit(SPhTradeState &st,const SPhTradeCfg &cfg,
                                const ENUM_PH_REGIME regime,const double &rsi[],
                                const bool againstBosNow)
  {
   PhTrade_ClearAgainstLock(st);
   if(!cfg.enable || !againstBosNow)
      return;
   if(regime != PH_BULLISH && regime != PH_BEARISH)
      return;
   Print("Phase Trade: against Div+BOS — no cut, trades continue");
  }

// Realign unlock — DISABLED (no sequence lock)
void PhTrade_CheckRealignUnlock(SPhTradeState &st,const ENUM_PH_REGIME regime,
                                const double &rsi[])
  {
   PhTrade_ClearAgainstLock(st);
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
   // #region agent log
   double dbgFast = 0.0, dbgSlow = 0.0;
   PhTrade_MaSnapshot(dbgFast,dbgSlow);
   const datetime dbgBar = iTime(_Symbol,_Period,1);
   const int dbgOpen = PhTrade_CountOurs(cfg.magic);
   string dbgBlock = "";
   // #endregion
   if(!cfg.enable)
     {
      dbgBlock = "disabled";
      // #region agent log
      PhDbg_Log("H1","Phase_Trade.mqh:PhTrade_Open","blocked",
         StringFormat("{\"comment\":\"%s\",\"type\":%d,\"block\":\"%s\",\"fast\":%.5f,\"slow\":%.5f,\"whiteAboveRed\":%s,\"bar\":\"%s\",\"open\":%d}",
            comment,(int)type,dbgBlock,dbgFast,dbgSlow,(dbgFast>dbgSlow?"true":"false"),
            TimeToString(dbgBar),dbgOpen));
      // #endregion
      return(false);
     }
   if(st.dayStopped)
     {
      dbgBlock = "dayStopped";
      // #region agent log
      PhDbg_Log("H1","Phase_Trade.mqh:PhTrade_Open","blocked",
         StringFormat("{\"comment\":\"%s\",\"type\":%d,\"block\":\"%s\",\"fast\":%.5f,\"slow\":%.5f,\"bar\":\"%s\",\"open\":%d}",
            comment,(int)type,dbgBlock,dbgFast,dbgSlow,TimeToString(dbgBar),dbgOpen));
      // #endregion
      return(false);
     }
   if(st.seqLocked)
     {
      dbgBlock = "seqLocked";
      // #region agent log
      PhDbg_Log("H1","Phase_Trade.mqh:PhTrade_Open","blocked",
         StringFormat("{\"comment\":\"%s\",\"type\":%d,\"block\":\"%s\",\"fast\":%.5f,\"slow\":%.5f,\"bar\":\"%s\"}",
            comment,(int)type,dbgBlock,dbgFast,dbgSlow,TimeToString(dbgBar)));
      // #endregion
      return(false);
     }
   if(cfg.maxOpen > 0 && PhTrade_CountOurs(cfg.magic) >= cfg.maxOpen)
     {
      dbgBlock = "maxOpen";
      // #region agent log
      PhDbg_Log("H1","Phase_Trade.mqh:PhTrade_Open","blocked",
         StringFormat("{\"comment\":\"%s\",\"type\":%d,\"block\":\"%s\",\"fast\":%.5f,\"slow\":%.5f,\"bar\":\"%s\",\"open\":%d,\"maxOpen\":%d}",
            comment,(int)type,dbgBlock,dbgFast,dbgSlow,TimeToString(dbgBar),dbgOpen,cfg.maxOpen));
      // #endregion
      return(false);
     }
   if(!PhTrade_MaAllows(cfg,type))
     {
      dbgBlock = "maGate";
      // #region agent log
      PhDbg_Log("H2","Phase_Trade.mqh:PhTrade_Open","maGate-block",
         StringFormat("{\"comment\":\"%s\",\"type\":%d,\"block\":\"%s\",\"fast\":%.5f,\"slow\":%.5f,\"whiteAboveRed\":%s,\"bar\":\"%s\",\"maGate\":%s}",
            comment,(int)type,dbgBlock,dbgFast,dbgSlow,(dbgFast>dbgSlow?"true":"false"),
            TimeToString(dbgBar),(cfg.maGate?"true":"false")));
      // #endregion
      return(false);
     }

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

   // #region agent log
   const bool dbgOk = PhTrade_Send(req,res);
   PhDbg_Log("H3","Phase_Trade.mqh:PhTrade_Open",dbgOk?"opened":"sendFail",
      StringFormat("{\"comment\":\"%s\",\"type\":%d,\"fast\":%.5f,\"slow\":%.5f,\"whiteAboveRed\":%s,\"bar\":\"%s\",\"retcode\":%d}",
         comment,(int)type,dbgFast,dbgSlow,(dbgFast>dbgSlow?"true":"false"),
         TimeToString(dbgBar),res.retcode));
   return(dbgOk);
   // #endregion
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

double PhTrade_BasketFloat(const long magic)
  {
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PhTrade_IsOurs(ticket,magic))
         continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return(sum);
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

// Soft CloseAll: skip while basket float < 0 (e.g. sells below, FVG/SL zone above)
int PhTrade_CloseAllSoft(SPhTradeState &st,const SPhTradeCfg &cfg,const string why)
  {
   if(!cfg.enable)
      return(0);
   double fl = PhTrade_BasketFloat(cfg.magic);
   if(fl < 0.0)
     {
      Print("Phase Trade: skip CloseAll [",why,"] float=",
            DoubleToString(fl,2)," — wait until plus");
      return(0);
     }
   return(PhTrade_CloseAll(st,cfg));
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

// Stack-loss CloseAll — DISABLED (BOS/against-spike pe false cut)
bool PhTrade_PollStackLossClose(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   return(false);
  }

datetime PhTrade_DayStamp(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t,dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return(StructToTime(dt));
  }

void PhTrade_EnsureInitEq(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   if(st.initEq > 0.0)
      return;
   if(cfg.initDeposit > 0.0)
      st.initEq = cfg.initDeposit;
   else
      st.initEq = AccountInfoDouble(ACCOUNT_BALANCE);
   if(st.initEq <= 0.0)
      st.initEq = AccountInfoDouble(ACCOUNT_EQUITY);
   Print("Phase Trade: initEq freeze=",DoubleToString(st.initEq,2));
  }

void PhTrade_RollDay(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   datetime day = PhTrade_DayStamp(TimeCurrent());
   if(day <= 0)
      return;
   PhTrade_EnsureInitEq(st,cfg);
   if(st.dayStamp == day)
      return;

   st.dayStamp   = day;
   st.dayStartEq = AccountInfoDouble(ACCOUNT_EQUITY);
   st.dayStopped = false;
   if(st.runStartEq <= 0.0)
      st.runStartEq = st.dayStartEq;
   Print("Phase Trade: new day bal=",DoubleToString(st.dayStartEq,2),
         " initEq=",DoubleToString(st.initEq,2),
         " +",DoubleToString(cfg.dailyProfitPct,1),"% / -",
         DoubleToString(cfg.dailyLossPct,1),"% of init");
  }

// Floating profit ≥ book % of frozen init deposit → CloseAll
bool PhTrade_PollProfitHalfClose(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   if(!cfg.enable || cfg.bookProfitPct <= 0.0)
      return(false);
   PhTrade_RollDay(st,cfg);
   PhTrade_EnsureInitEq(st,cfg);
   if(PhTrade_CountOurs(cfg.magic) <= 0)
      return(false);
   if(st.initEq <= 0.0)
      return(false);

   double fl = PhTrade_BasketFloat(cfg.magic);
   const double need = st.initEq * (cfg.bookProfitPct / 100.0);
   if(fl < need)
      return(false);

   int n = PhTrade_CloseAll(st,cfg);
   Print("Phase Trade: book profit≥",DoubleToString(cfg.bookProfitPct,1),
         "% init ",DoubleToString(st.initEq,2)," → CloseAll n=",n,
         " float=",DoubleToString(fl,2)," need≥",DoubleToString(need,2));
   return(n > 0);
  }

// Today's P/L vs ±% of frozen initEq → CloseAll + stop until next day
bool PhTrade_PollDailyTarget(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   if(!cfg.enable)
      return(false);
   if(cfg.dailyProfitPct <= 0.0 && cfg.dailyLossPct <= 0.0)
      return(false);

   PhTrade_RollDay(st,cfg);
   PhTrade_EnsureInitEq(st,cfg);
   if(st.dayStopped)
      return(false);
   if(st.initEq <= 0.0 || st.dayStartEq <= 0.0)
      return(false);

   const double pnl = AccountInfoDouble(ACCOUNT_EQUITY) - st.dayStartEq;
   const double profitNeed = st.initEq * (cfg.dailyProfitPct / 100.0);
   const double lossNeed   = st.initEq * (cfg.dailyLossPct / 100.0);
   bool hitProfit = (cfg.dailyProfitPct > 0.0 && pnl + 1e-8 >= profitNeed);
   bool hitLoss   = (cfg.dailyLossPct > 0.0 && pnl - 1e-8 <= -lossNeed);
   if(!hitProfit && !hitLoss)
      return(false);

   int n = PhTrade_CloseAll(st,cfg);
   st.dayStopped = true;
   PhTrade_ResetArms(st);
   Print("Phase Trade: daily ",(hitLoss ? "LOSS" : "PROFIT"),
         " stop pnl=",DoubleToString(pnl,2)," initEq=",DoubleToString(st.initEq,2),
         " need=",DoubleToString((hitLoss ? lossNeed : profitNeed),2),
         " → CloseAll n=",n," STOP until next day");
   return(true);
  }

// Open basket float ≤ −trailLossPct of initEq → CloseAll (no day stop)
bool PhTrade_PollTrailLoss(SPhTradeState &st,const SPhTradeCfg &cfg)
  {
   if(!cfg.enable || cfg.trailLossPct <= 0.0)
      return(false);
   if(PhTrade_CountOurs(cfg.magic) <= 0)
      return(false);

   PhTrade_EnsureInitEq(st,cfg);
   if(st.initEq <= 0.0)
      return(false);

   const double fl   = PhTrade_BasketFloat(cfg.magic);
   const double need = st.initEq * (cfg.trailLossPct / 100.0);
   if(fl > -need + 1e-8)
      return(false);

   int n = PhTrade_CloseAll(st,cfg);
   Print("Phase Trade: trail LOSS float=",DoubleToString(fl,2),
         " ≤ -",DoubleToString(need,2)," (",DoubleToString(cfg.trailLossPct,1),
         "% init ",DoubleToString(st.initEq,2),") → CloseAll n=",n);
   return(n > 0);
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

   // SL cascade CloseAll — DISABLED (sirf broker us ticket band kare; baqi continue)
   Print("Phase Trade: SL hit noted — no CloseAll cascade (trades continue)");
   return(true);
  }

void PhTrade_CheckBounce(SPhTradeState &st,const SPhTradeCfg &cfg,
                         const ENUM_PH_REGIME regime,const double &rsi[])
  {
   if(!cfg.enable)
      return;
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
