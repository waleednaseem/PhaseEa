//+------------------------------------------------------------------+
//|                                                       Phase.mq5  |
//+------------------------------------------------------------------+
#property copyright "Phase"
#property version   "1.47"

#include "Include/Phase_Types.mqh"
#include "Include/Phase_Regime.mqh"
#include "Include/Phase_Draw.mqh"
#include "Include/Phase_Dash.mqh"
#include "Include/Phase_DivEngine.mqh"
#include "Include/Phase_Trade.mqh"
#include "Include/Phase_PriceSR.mqh"

input group "=== RSI / CB Zones ==="
input int                InpRsiPeriod      = 14;
input ENUM_APPLIED_PRICE InpAppliedPrice   = PRICE_CLOSE;
input int                InpHistoryBars    = 500;
input double             InpBullFloor      = 40.0;
input double             InpBullHard       = 35.0;
input double             InpBearCapLo      = 60.0;
input double             InpBearCap        = 65.0;
input double             InpRsiTol         = 0.5;
input int                InpConfirmBars    = 2;
input int                InpHoldBars       = 3;
input int                InpCapFailCount   = 2;
input int                InpSwingStrength  = 2;

input group "=== Divergence / BOS / HD ==="
input bool               InpShowDiv        = true;
input bool               InpShowDivLines   = true;
input bool               InpShowDivBoxes   = true;   // HD boxes
input bool               InpShowBos        = true;   // white BOS line
input int                InpPivotLeft      = 2;
input int                InpPivotRight     = 2;
input int                InpMinDivBars     = 3;
input int                InpMaxDivBars     = 100;
input int                InpMinHdBars      = 4;
input int                InpMaxHdBars      = 40;
input int                InpBosMaxCandles  = 50;
input int                InpDivLookback    = 400;
input EPh_BosBreakMode   InpBosBreakMode   = Ph_BOS_CLOSE;
input double             InpRsiDeadLow     = 35.0;
input double             InpRsiDeadHigh    = 65.0;
input int                InpDivLineWidth   = 2;
input color              InpColorBearDiv   = clrRed;
input color              InpColorBullDiv   = clrLime;
input color              InpColorHidBear   = clrYellow;
input color              InpColorHidBull   = clrSkyBlue;
input color              InpColorHidBearBox = clrYellow;
input color              InpColorHidBullBox = clrSkyBlue;

input group "=== Display ==="
input bool               InpShowBackground = true;
input bool               InpShowHistory    = true;
input bool               InpShowBoxes      = true;
input bool               InpShowSignals    = true;
input bool               InpShowRsiSR      = true;
input bool               InpShowDash       = true;
input bool               InpAttachRsi      = true;
input color              InpBullColor      = C'12,55,32';
input color              InpBearColor      = C'70,18,22';
input color              InpNeutralColor   = clrBlack;
input color              InpBullBoxColor   = C'0,140,70';
input color              InpBearBoxColor   = C'160,40,45';
input color              InpBuySignalClr   = clrLime;
input color              InpSellSignalClr  = clrRed;
input color              InpSupportClr     = clrAqua;
input color              InpResistClr      = clrOrangeRed;

input group "=== Trade ==="
input bool               InpEnableTrade     = true;
input double             InpLot             = 0.01;
input int                InpSL_Pips         = 800;   // min SL fallback (pips); prefer 2nd FVG
input long               InpTradeMagic      = 140001;
input int                InpTradeDeviation  = 30;
input bool               InpShowPriceSR     = true;  // last-100 price S&R lines
input int                InpPriceSRBars     = 100;

input group "=== FVG ==="
input bool               InpShowFvg             = true;
input int                InpFvgLookbackBars     = 800;
input int                InpFvgMinGapPoints     = 30;
input int                InpFvgMaxShow          = 12;
input int                InpFvgMinWidthBars     = 30;
input int                InpFvgMaxWidthBars     = 1000;
input int                InpFvgWidthBars        = 1000;
input color              InpColorFvgFill        = C'222,184,135'; // brown open
input color              InpColorFvgBorder      = C'101,67,33';
input color              InpColorFvgFillFilled  = C'105,105,105'; // grey iFVG
input color              InpColorFvgBorderFilled = C'64,64,64';

input group "=== Dashboard / Loss ==="
input bool               InpShowLossMonitor = true;
input long               InpLossMagic       = 0;   // 0 = use InpTradeMagic
input bool               InpResetLossStats  = false;
input color              InpDashTextClr     = clrWhite;
input color              InpDashBackClr     = clrBlack;
input color              InpDashBorderClr   = C'60,60,66';
input color              InpLossClr         = clrOrangeRed;
input color              InpProfitClr       = clrLime;

SPhConfig      g_cfg;
SPhSRList      g_srList;
SPhWalk        g_walk;
SPhDash        g_dash;
SPhDivCfg      g_divCfg;
SPhDivState    g_div;
SPhTradeCfg    g_tradeCfg;
SPhTradeState  g_trade;
SPhPriceSR     g_priceSR;
bool           g_ignited    = false;
int            g_rsiHandle  = INVALID_HANDLE;
int            g_rsiWindow  = -1;
datetime       g_lastBar    = 0;
ENUM_PH_REGIME g_lastRegime = PH_NEUTRAL;
double         g_rsi[];
ENUM_PH_REGIME g_regimes[];
datetime       g_times[];

long LossMagicEffective()
  {
   return(InpLossMagic != 0 ? InpLossMagic : InpTradeMagic);
  }

void LoadConfig()
  {
   PhConfigLoad(g_cfg,
                InpBullFloor,InpBullHard,InpBearCapLo,InpBearCap,
                InpRsiTol,InpConfirmBars,InpHoldBars,InpCapFailCount,
                InpHistoryBars,InpSwingStrength);

   PhDiv_CfgDefault(g_divCfg);
   g_divCfg.pivotLeft     = InpPivotLeft;
   g_divCfg.pivotRight    = InpPivotRight;
   g_divCfg.minDivBars    = InpMinDivBars;
   g_divCfg.maxDivBars    = InpMaxDivBars;
   g_divCfg.minHdBars     = InpMinHdBars;
   g_divCfg.maxHdBars     = InpMaxHdBars;
   g_divCfg.bosMaxCandles = InpBosMaxCandles;
   g_divCfg.lookback      = InpDivLookback;
   g_divCfg.deadLow       = InpRsiDeadLow;
   g_divCfg.deadHigh      = InpRsiDeadHigh;
   g_divCfg.bosMode       = InpBosBreakMode;
   g_divCfg.showLines     = InpShowDivLines;
   g_divCfg.showBoxes     = InpShowDivBoxes;
   g_divCfg.showBos       = InpShowBos;
   g_divCfg.bearClr       = InpColorBearDiv;
   g_divCfg.bullClr       = InpColorBullDiv;
   g_divCfg.hidBearClr    = InpColorHidBear;
   g_divCfg.hidBullClr    = InpColorHidBull;
   g_divCfg.hidBearBox    = InpColorHidBearBox;
   g_divCfg.hidBullBox    = InpColorHidBullBox;
   g_divCfg.lineWidth     = InpDivLineWidth;

   PhTrade_CfgDefault(g_tradeCfg);
   g_tradeCfg.enable    = InpEnableTrade;
   g_tradeCfg.lot       = InpLot;
   g_tradeCfg.slPips    = MathMax(800,InpSL_Pips);
   g_tradeCfg.tpPips    = 0;   // no fixed TP — close on Div / regime
   g_tradeCfg.magic     = InpTradeMagic;
   g_tradeCfg.zoneTol   = InpRsiTol;
   g_tradeCfg.deviation = InpTradeDeviation;
   g_tradeCfg.fvgLookback  = InpFvgLookbackBars;
   g_tradeCfg.fvgMinGapPts = InpFvgMinGapPoints;
  }

void AttachPhaseRsi()
  {
   int wins = (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL);
   for(int w = wins - 1; w >= 0; w--)
     {
      for(int i = ChartIndicatorsTotal(0,w) - 1; i >= 0; i--)
        {
         string name = ChartIndicatorName(0,w,i);
         if(StringFind(name,"Phase_RSI") == 0)
            ChartIndicatorDelete(0,w,name);
        }
     }
   g_rsiWindow = -1;

   int h = iCustom(_Symbol,_Period,"Phase_RSI",InpRsiPeriod,InpAppliedPrice,true);
   if(h == INVALID_HANDLE)
     {
      Print("Phase: compile Indicators/Phase_RSI.mq5 first");
      return;
     }
   int sub = (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL);
   if(!ChartIndicatorAdd(0,sub,h))
     {
      Print("Phase: ChartIndicatorAdd failed err=",GetLastError());
      IndicatorRelease(h);
      return;
     }
   g_rsiWindow = sub;
  }

void PaintDash(const bool forceCalc)
  {
   const ENUM_PH_REGIME cur = (ArraySize(g_regimes) > 1 ? g_regimes[1] : PH_NEUTRAL);
   PhDash_PaintAll(g_dash,InpShowDash,InpShowLossMonitor,g_cfg,forceCalc,
                   LossMagicEffective(),false,
                   InpDashTextClr,InpDashBackClr,InpDashBorderClr,
                   InpLossClr,InpProfitClr,cur);
  }

void ApplyTradeExitsAndEntries()
  {
   const ENUM_PH_REGIME cur = (ArraySize(g_regimes) > 1 ? g_regimes[1] : PH_NEUTRAL);
   if(cur != g_lastRegime)
     {
      int n = PhTrade_CloseAll(g_trade,g_tradeCfg);
      if(n > 0)
         Print("Phase Trade: regime change CloseAll n=",n,
               " ",EnumToString(g_lastRegime)," -> ",EnumToString(cur));
      PhTrade_ResetArms(g_trade);
      PhTrade_ClearFvgArm(g_trade);
      PhPriceSR_ClearArm(g_priceSR);
      if(PhTrade_IsLocked(g_trade))
         PhTrade_UnlockSeq(g_trade);
     }
   PhTrade_CheckBounce(g_trade,g_tradeCfg,cur,g_rsi);
   PhPriceSR_Scan(g_priceSR,g_rsi,g_times,g_rsiWindow,InpPriceSRBars,2,InpShowPriceSR);
   PhPriceSR_CheckTrade(g_priceSR,g_trade,g_tradeCfg,cur,g_rsi);
   PhTrade_CheckFvgReject(g_trade,g_tradeCfg,cur);
  }

// Regime = parent.
// Against Div+BOS → CloseAll + lock | Support Div+BOS → unlock only (same-side).
// Opposite BOS never unlocks (SELL: bull/buy BOS; BUY: bear/sell BOS).
void ApplyDivTradeExits()
  {
   const ENUM_PH_REGIME cur = (ArraySize(g_regimes) > 1 ? g_regimes[1] : PH_NEUTRAL);
   if(cur != PH_BULLISH && cur != PH_BEARISH)
      return;

   const bool againstBos = (cur == PH_BULLISH) ? g_div.newBosBreakBear : g_div.newBosBreakBull;
   const bool supportBos = (cur == PH_BULLISH) ? g_div.newBosBreakBull : g_div.newBosBreakBear;

   if(againstBos)
     {
      int n = PhTrade_CloseAll(g_trade,g_tradeCfg);
      PhTrade_LockAgainstDiv(g_trade);
      PhTrade_ClearFvgArm(g_trade);
      PhPriceSR_ClearArm(g_priceSR);
      Print("Phase Trade: against Div+BOS → CloseAll n=",n,
            " LOCKED (",EnumToString(cur),") — opposite BOS never unlocks");
      return; // same bar: against wins over support
     }

   if(supportBos)
     {
      if(PhTrade_IsLocked(g_trade))
        {
         PhTrade_UnlockSeq(g_trade);
         Print("Phase Trade: support Div+BOS → UNLOCK (",EnumToString(cur),")");
        }
     }
  }

// Regime = parent. Unlock+open ONLY same-side HD.
// SELL → yellow hidden bear only | BUY → sky hidden bull only.
// Opposite HD: no unlock, no open.
void ApplyHdTradeEntries()
  {
   if(!InpEnableTrade)
      return;
   const ENUM_PH_REGIME cur = (ArraySize(g_regimes) > 1 ? g_regimes[1] : PH_NEUTRAL);

   if(cur == PH_BULLISH)
     {
      if(g_div.newHiddenBull)
        {
         PhTrade_UnlockSeq(g_trade);
         if(PhTrade_Open(g_trade,g_tradeCfg,ORDER_TYPE_BUY,"PH_HD"))
            Print("Phase Trade: BUY unlock+entry on support HD (hidden bull / sky)");
        }
      if(g_div.newHiddenBear)
         Print("Phase Trade: ignore sell HD (yellow) in BUY regime — no unlock/open");
     }
   else if(cur == PH_BEARISH)
     {
      if(g_div.newHiddenBear)
        {
         PhTrade_UnlockSeq(g_trade);
         if(PhTrade_Open(g_trade,g_tradeCfg,ORDER_TYPE_SELL,"PH_HD"))
            Print("Phase Trade: SELL unlock+entry on support HD (hidden bear / yellow)");
        }
      if(g_div.newHiddenBull)
         Print("Phase Trade: ignore buy HD (sky) in SELL regime — no unlock/open");
     }
  }

void PaintFvg()
  {
   PhFvg_Refresh(0,_Symbol,_Period,InpFvgLookbackBars,InpShowFvg,
                 InpFvgWidthBars,InpFvgMinWidthBars,InpFvgMaxWidthBars,
                 InpFvgMinGapPoints,InpFvgMaxShow,
                 InpColorFvgFill,InpColorFvgBorder,
                 InpColorFvgFillFilled,InpColorFvgBorderFilled);
  }

void PaintAll(const int hist)
  {
   g_lastRegime = g_regimes[1];
   PhUpdateBackground(InpShowBackground,g_lastRegime);

   if(InpShowHistory)
      PhPaintHistory(g_regimes,hist,InpBullColor,InpBearColor,InpNeutralColor);
   if(InpShowBoxes)
      PhPaintBoxes(g_regimes,hist,InpBullBoxColor,InpBearBoxColor);
   if(InpShowSignals)
      PhPaintSignals(g_regimes,hist,InpBuySignalClr,InpSellSignalClr);
   if(InpShowRsiSR)
      PhPaintRsiSR(g_srList,g_rsiWindow,InpSupportClr,InpResistClr);

   PaintFvg();
   PaintDash(false);
   ChartRedraw(0);
  }

bool CopyRsiTimes(int &hist)
  {
   int bars = Bars(_Symbol,_Period);
   int need = g_cfg.historyBars + 20;
   if(need > bars) need = bars;
   if(need < 30)   return(false);

   ArraySetAsSeries(g_rsi,true);
   ArraySetAsSeries(g_times,true);
   if(CopyBuffer(g_rsiHandle,0,0,need,g_rsi) < 30) return(false);
   if(CopyTime(_Symbol,_Period,0,need,g_times) < 30) return(false);

   hist = MathMin(g_cfg.historyBars,ArraySize(g_rsi) - 2);
   if(hist < 5) return(false);

   for(int i = 0; i < ArraySize(g_rsi); i++)
     {
      if(g_rsi[i] == EMPTY_VALUE || g_rsi[i] < 0.0 || g_rsi[i] > 100.0)
         g_rsi[i] = 50.0;
     }
   return(true);
  }

void RunDivScan(const bool fullHistory)
  {
   if(!InpShowDiv && !InpEnableTrade)
      return;
   g_div.rsiHandle = g_rsiHandle;
   g_div.rsiWindow = g_rsiWindow;
   if(fullHistory)
      PhDiv_ScanHistory(g_div,g_divCfg);
   else
      PhDiv_ProcessLiveBar(g_div,g_divCfg);
   if(InpShowDiv)
      Ph_UpdateHidButton(0,g_div.showHidden);
  }

void IgniteHistory()
  {
   int hist = 0;
   if(!CopyRsiTimes(hist))
      return;

   ArrayResize(g_regimes,hist + 1);
   ArrayInitialize(g_regimes,(int)PH_NEUTRAL);
   PhBuildRegimes(g_rsi,g_times,hist,g_cfg,g_regimes,g_srList,g_walk);
   g_ignited = true;
   PaintAll(hist);
   RunDivScan(true);
   Print("Phase: ignited ",hist," bars + Div/BOS/HD");
  }

void AdvanceBar()
  {
   if(!g_ignited)
     {
      IgniteHistory();
      return;
     }

   int hist = 0;
   if(!CopyRsiTimes(hist))
      return;

   PhTrade_SetMarkContext(g_rsiWindow,(ArraySize(g_rsi) > 1 ? g_rsi[1] : 0.0));
   PhRegimeAdvance(g_walk,g_srList,g_rsi,g_times,hist,g_cfg,g_regimes);
   ApplyTradeExitsAndEntries();
   PaintAll(hist);
   RunDivScan(false);
   ApplyDivTradeExits();
   ApplyHdTradeEntries();
   if(InpEnableTrade)
     {
      const ENUM_PH_REGIME cur = (ArraySize(g_regimes) > 1 ? g_regimes[1] : PH_NEUTRAL);
      PhTrade_CheckRealignUnlock(g_trade,cur,g_rsi);
     }
  }

int OnInit()
  {
   LoadConfig();
   ArraySetAsSeries(g_rsi,true);
   ArraySetAsSeries(g_times,true);
   PhSRListClear(g_srList);
   PhWalkReset(g_walk);
   PhDash_Init(g_dash);
   PhDiv_StateInit(g_div);
   PhTrade_Init(g_trade,g_tradeCfg);
   PhPriceSR_Init(g_priceSR);
   g_ignited = false;

   g_rsiHandle = iRSI(_Symbol,_Period,InpRsiPeriod,InpAppliedPrice);
   if(g_rsiHandle == INVALID_HANDLE)
     {
      Print("Phase: iRSI failed");
      return(INIT_FAILED);
     }
   if(InpShowDash)
      PhDash_CreateHandles(g_dash,InpRsiPeriod,InpAppliedPrice);
   if(InpResetLossStats)
     {
      long lm = LossMagicEffective();
      GlobalVariableSet("PH_LM_MaxFloat_" + IntegerToString(lm) + "_" + _Symbol,0.0);
      GlobalVariableSet("PH_LM_MaxDD_" + IntegerToString(lm) + "_" + _Symbol,0.0);
     }
   if(InpAttachRsi)
      AttachPhaseRsi();

   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   EventSetTimer(1);
   IgniteHistory();
   PaintDash(true);
   if(InpShowDiv)
      Ph_UpdateHidButton(0,g_div.showHidden);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PhDeleteAll();
   PhFvg_DeleteObjects();
   PhFvg_CacheClear();
   PhPriceSR_DeleteObjects();
   PhDash_Release(g_dash);
   g_ignited = false;
   if(g_rsiHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_rsiHandle);
      g_rsiHandle = INVALID_HANDLE;
     }
   if(InpAttachRsi && g_rsiWindow >= 0)
     {
      for(int i = ChartIndicatorsTotal(0,g_rsiWindow) - 1; i >= 0; i--)
        {
         string name = ChartIndicatorName(0,g_rsiWindow,i);
         if(StringFind(name,"Phase_RSI") == 0)
            ChartIndicatorDelete(0,g_rsiWindow,name);
        }
     }
   ChartRedraw(0);
  }

void OnTick()
  {
   if(InpEnableTrade)
     {
      if(ArraySize(g_rsi) > 1)
         PhTrade_SetMarkContext(g_rsiWindow,g_rsi[1]);
      PhTrade_PollStackLossClose(g_trade,g_tradeCfg);
      PhTrade_PollSlLock(g_trade,g_tradeCfg);
     }

   datetime t = iTime(_Symbol,_Period,0);
   if(t == 0 || t == g_lastBar) return;
   g_lastBar = t;
   AdvanceBar();
  }

void OnTimer()
  {
   if(InpEnableTrade)
     {
      if(ArraySize(g_rsi) > 1)
         PhTrade_SetMarkContext(g_rsiWindow,g_rsi[1]);
      PhTrade_PollStackLossClose(g_trade,g_tradeCfg);
      PhTrade_PollSlLock(g_trade,g_tradeCfg);
     }
   if(InpShowBackground) PhResizeBg();
   if(InpShowDash || InpShowLossMonitor)
      PaintDash(false);
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == Ph_HidBtnName())
     {
      g_div.showHidden = !g_div.showHidden;
      PhDiv_RefreshHiddenVisuals(g_div,g_divCfg);
      ChartRedraw(0);
      return;
     }
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      if(InpShowBackground) PhResizeBg();
      if(InpShowDash || InpShowLossMonitor)
         PaintDash(false);
      if(InpShowDiv)
         Ph_UpdateHidButton(0,g_div.showHidden);
     }
  }
//+------------------------------------------------------------------+
