//+------------------------------------------------------------------+
//|                                               Phase_Dash.mqh     |
//| Compact top-right MTF dots + LOSS panel (F2E-style, no blink)    |
//+------------------------------------------------------------------+
#ifndef PHASE_DASH_MQH
#define PHASE_DASH_MQH

#include "Phase_Types.mqh"
#include "Phase_Regime.mqh"
#include "Phase_Draw.mqh"

#define PH_DASH_N       5
#define PH_DASH_MR      10
#define PH_DASH_W       118
#define PH_DASH_Y0      10
#define PH_DASH_ROW     15
#define PH_DASH_PAD     5
#define PH_DASH_GAP     5
#define PH_DASH_DOT     9

const ENUM_TIMEFRAMES PH_DASH_TF[PH_DASH_N] =
  { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1 };

const string PH_DASH_LBL[PH_DASH_N] =
  { "M1", "M5", "M15", "M30", "H1" };

struct SPhDash
  {
   int            rsiH[PH_DASH_N];
   ENUM_PH_REGIME reg[PH_DASH_N];
   ENUM_PH_REGIME painted[PH_DASH_N];
   datetime       lastBar[PH_DASH_N];
   bool           ready;
   bool           uiBuilt;
   int            lossY;
  };

void PhDash_Init(SPhDash &d)
  {
   d.ready   = false;
   d.uiBuilt = false;
   d.lossY   = PH_DASH_Y0;
   for(int i = 0; i < PH_DASH_N; i++)
     {
      d.rsiH[i]    = INVALID_HANDLE;
      d.reg[i]     = PH_NEUTRAL;
      d.painted[i] = (ENUM_PH_REGIME)(-1);
      d.lastBar[i] = 0;
     }
  }

void PhDash_Release(SPhDash &d)
  {
   for(int i = 0; i < PH_DASH_N; i++)
     {
      if(d.rsiH[i] != INVALID_HANDLE)
        {
         IndicatorRelease(d.rsiH[i]);
         d.rsiH[i] = INVALID_HANDLE;
        }
     }
   d.ready   = false;
   d.uiBuilt = false;
  }

bool PhDash_CreateHandles(SPhDash &d,const int rsiPeriod,const ENUM_APPLIED_PRICE price)
  {
   PhDash_Release(d);
   PhDash_Init(d);
   for(int i = 0; i < PH_DASH_N; i++)
     {
      d.rsiH[i] = iRSI(_Symbol,PH_DASH_TF[i],rsiPeriod,price);
      if(d.rsiH[i] == INVALID_HANDLE)
        {
         Print("Phase Dash: iRSI failed tf=",EnumToString(PH_DASH_TF[i]));
         PhDash_Release(d);
         return(false);
        }
     }
   d.ready = true;
   return(true);
  }

ENUM_PH_REGIME PhDash_CalcOne(const int rsiHandle,const ENUM_TIMEFRAMES tf,
                              const SPhConfig &cfg,const int wantHist)
  {
   if(rsiHandle == INVALID_HANDLE)
      return(PH_NEUTRAL);

   int bars = Bars(_Symbol,tf);
   int need = wantHist + 20;
   if(need > bars) need = bars;
   if(need < 40)
      return(PH_NEUTRAL);

   double rsi[];
   datetime times[];
   ArraySetAsSeries(rsi,true);
   ArraySetAsSeries(times,true);
   if(CopyBuffer(rsiHandle,0,0,need,rsi) < 30)
      return(PH_NEUTRAL);
   if(CopyTime(_Symbol,tf,0,need,times) < 30)
      return(PH_NEUTRAL);

   int hist = MathMin(wantHist,ArraySize(rsi) - 2);
   if(hist < 20)
      return(PH_NEUTRAL);

   for(int i = 0; i < ArraySize(rsi); i++)
     {
      if(rsi[i] == EMPTY_VALUE || rsi[i] < 0.0 || rsi[i] > 100.0)
         rsi[i] = 50.0;
     }

   ENUM_PH_REGIME regimes[];
   ArrayResize(regimes,hist + 1);
   ArrayInitialize(regimes,(int)PH_NEUTRAL);
   SPhWalk w;
   SPhSRList L;
   PhBuildRegimes(rsi,times,hist,cfg,regimes,L,w);
   return(regimes[1]);
  }

void PhDash_Refresh(SPhDash &d,const SPhConfig &cfg,const bool force)
  {
   if(!d.ready)
      return;
   const int want = MathMin(220,MathMax(80,cfg.historyBars));
   for(int i = 0; i < PH_DASH_N; i++)
     {
      datetime t = iTime(_Symbol,PH_DASH_TF[i],0);
      if(!force && t != 0 && t == d.lastBar[i])
         continue;
      d.lastBar[i] = t;
      d.reg[i] = PhDash_CalcOne(d.rsiH[i],PH_DASH_TF[i],cfg,want);
     }
  }

// --- UI helpers: create once, update props (no delete = no blink) ---
int PhDash_XL()
  {
   return(PH_DASH_MR + PH_DASH_W); // left edge distance from right
  }

void PhDash_SetRect(const string name,const int xFromRight,const int y,
                    const int w,const int h,const color bg,const color border)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,xFromRight);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
  }

void PhDash_SetLabel(const string name,const int xFromRight,const int y,
                     const string text,const color clr,const int fontSz)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,xFromRight);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSz);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,101);
  }

void PhDash_SetDot(const string name,const int xFromRight,const int y,const color clr)
  {
   PhDash_SetRect(name,xFromRight,y,PH_DASH_DOT,PH_DASH_DOT,clr,clr);
  }

color PhDash_RegColor(const ENUM_PH_REGIME r)
  {
   if(r == PH_BULLISH) return C'20,160,70';
   if(r == PH_BEARISH) return C'200,45,55';
   return C'70,70,78';
  }

string PhDash_Money(const double v)
  {
   return(DoubleToString(v,2));
  }

string PhDash_LossGvFloat(const long magic)
  {
   return("PH_LM_MaxFloat_" + IntegerToString(magic) + "_" + _Symbol);
  }

string PhDash_LossGvDd(const long magic)
  {
   return("PH_LM_MaxDD_" + IntegerToString(magic) + "_" + _Symbol);
  }

double PhDash_LossMaxDd(const long magic,const double curFloat,double &cumClosed)
  {
   cumClosed = 0.0;
   datetime times[];
   double   pnls[];
   ArrayResize(times,0);
   ArrayResize(pnls,0);

   if(HistorySelect(0,TimeCurrent()))
     {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         long entry = HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
            continue;
         if(magic != 0 && HistoryDealGetInteger(ticket,DEAL_MAGIC) != magic)
            continue;
         if(HistoryDealGetString(ticket,DEAL_SYMBOL) != _Symbol)
            continue;
         double pnl = HistoryDealGetDouble(ticket,DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket,DEAL_SWAP)
                      + HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         int n = ArraySize(times);
         ArrayResize(times,n + 1);
         ArrayResize(pnls,n + 1);
         times[n] = (datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
         pnls[n]  = pnl;
        }
     }

   // chronological sort (simple)
   int n = ArraySize(times);
   for(int a = 0; a < n; a++)
      for(int b = a + 1; b < n; b++)
         if(times[b] < times[a])
           {
            datetime tt = times[a]; times[a] = times[b]; times[b] = tt;
            double pp = pnls[a]; pnls[a] = pnls[b]; pnls[b] = pp;
           }

   double equity = 0.0;
   double peak   = 0.0;
   double maxDd  = 0.0;
   for(int i = 0; i < n; i++)
     {
      equity += pnls[i];
      cumClosed = equity;
      if(equity > peak)
         peak = equity;
      double dd = equity - peak;
      if(dd < maxDd)
         maxDd = dd;
     }
   // include open float vs peak of closed+float path
   double eqNow = cumClosed + curFloat;
   if(eqNow > peak)
      peak = eqNow;
   double ddNow = eqNow - peak;
   if(ddNow < maxDd)
      maxDd = ddNow;
   return(maxDd);
  }

// Returns Y just below regime panel
int PhDash_PaintRegime(SPhDash &d,const bool show,
                       const color textClr,const color backClr,const color borderClr)
  {
   const string pfx = g_phPrefix + "DASH_";
   if(!show || !d.ready)
     {
      PhDeleteByPrefix(pfx);
      d.uiBuilt = false;
      for(int i = 0; i < PH_DASH_N; i++)
         d.painted[i] = (ENUM_PH_REGIME)(-1);
      return(PH_DASH_Y0);
     }

   const int xL = PhDash_XL();
   const int rows = PH_DASH_N + 1; // title + TFs
   const int h = rows * PH_DASH_ROW + PH_DASH_PAD * 2;
   const int y = PH_DASH_Y0;

   PhDash_SetRect(pfx + "BG",xL,y,PH_DASH_W,h,backClr,borderClr);
   PhDash_SetLabel(pfx + "HD",xL - 6,y + PH_DASH_PAD,"PHASE",textClr,8);

   for(int i = 0; i < PH_DASH_N; i++)
     {
      const int rowY = y + PH_DASH_PAD + (i + 1) * PH_DASH_ROW;
      PhDash_SetLabel(pfx + "TF" + IntegerToString(i),
                      xL - 6,rowY,PH_DASH_LBL[i],textClr,9);
      // only touch dot colour when regime changed (anti-blink)
      if(d.reg[i] != d.painted[i] || !d.uiBuilt)
        {
         PhDash_SetDot(pfx + "DT" + IntegerToString(i),
                       xL - (PH_DASH_W - 18),rowY + 2,PhDash_RegColor(d.reg[i]));
         d.painted[i] = d.reg[i];
        }
     }
   d.uiBuilt = true;
   return(y + h + PH_DASH_GAP);
  }

void PhDash_PaintLoss(const bool show,const long magic,const bool resetPeaks,
                      const int y,
                      const color textClr,const color backClr,const color borderClr,
                      const color lossClr,const color profitClr)
  {
   const string pfx = g_phPrefix + "LOSS_";
   if(!show)
     {
      PhDeleteByPrefix(pfx);
      return;
     }

   string baskKey = PhDash_LossGvFloat(magic);
   string ddKey   = PhDash_LossGvDd(magic);
   double maxFloat = 0.0;
   double maxDd    = 0.0;
   if(resetPeaks)
     {
      GlobalVariableSet(baskKey,0.0);
      GlobalVariableSet(ddKey,0.0);
     }
   else
     {
      if(GlobalVariableCheck(baskKey))
         maxFloat = GlobalVariableGet(baskKey);
      if(GlobalVariableCheck(ddKey))
         maxDd = GlobalVariableGet(ddKey);
     }

   double curFloat = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      curFloat += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   if(curFloat < maxFloat)
      maxFloat = curFloat;
   GlobalVariableSet(baskKey,maxFloat);

   double cumClosed = 0.0;
   double ddNow = PhDash_LossMaxDd(magic,curFloat,cumClosed);
   if(ddNow < maxDd)
      maxDd = ddNow;
   GlobalVariableSet(ddKey,maxDd);

   double maxLossTrade = 0.0;
   int lossTrades = 0;
   int profitTrades = 0;
   if(HistorySelect(0,TimeCurrent()))
     {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         long entry = HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
            continue;
         if(magic != 0 && HistoryDealGetInteger(ticket,DEAL_MAGIC) != magic)
            continue;
         if(HistoryDealGetString(ticket,DEAL_SYMBOL) != _Symbol)
            continue;
         double pnl = HistoryDealGetDouble(ticket,DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket,DEAL_SWAP)
                      + HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         if(pnl < 0.0)
           {
            lossTrades++;
            if(pnl < maxLossTrade)
               maxLossTrade = pnl;
           }
         else if(pnl > 0.0)
            profitTrades++;
        }
     }

   const int xL = PhDash_XL();
   const int rows = 6;
   const int h = rows * PH_DASH_ROW + PH_DASH_PAD * 2;
   string cur = AccountInfoString(ACCOUNT_CURRENCY);

   PhDash_SetRect(pfx + "BG",xL,y,PH_DASH_W,h,backClr,borderClr);
   int ry = y + PH_DASH_PAD;
   PhDash_SetLabel(pfx + "H",xL - 6,ry,"LOSS [" + cur + "]",textClr,8);
   ry += PH_DASH_ROW;
   PhDash_SetLabel(pfx + "MF",xL - 6,ry,"MaxFloat " + PhDash_Money(maxFloat),lossClr,8);
   ry += PH_DASH_ROW;
   PhDash_SetLabel(pfx + "MD",xL - 6,ry,"MaxDD    " + PhDash_Money(maxDd),lossClr,8);
   ry += PH_DASH_ROW;
   PhDash_SetLabel(pfx + "ML",xL - 6,ry,"MaxLoss  " + PhDash_Money(maxLossTrade),lossClr,8);
   ry += PH_DASH_ROW;
   PhDash_SetLabel(pfx + "LT",xL - 6,ry,"LossTr   " + IntegerToString(lossTrades),lossClr,8);
   ry += PH_DASH_ROW;
   PhDash_SetLabel(pfx + "PT",xL - 6,ry,"ProfitTr " + IntegerToString(profitTrades),profitClr,8);
  }

void PhDash_PaintAll(SPhDash &d,const bool showRegime,const bool showLoss,
                     const SPhConfig &cfg,const bool forceCalc,
                     const long magic,const bool resetLoss,
                     const color textClr,const color backClr,const color borderClr,
                     const color lossClr,const color profitClr)
  {
   if(showRegime && d.ready)
      PhDash_Refresh(d,cfg,forceCalc);

   int y = PhDash_PaintRegime(d,showRegime,textClr,backClr,borderClr);
   d.lossY = y;
   PhDash_PaintLoss(showLoss,magic,resetLoss,y,textClr,backClr,borderClr,lossClr,profitClr);
  }

#endif
//+------------------------------------------------------------------+
