//+------------------------------------------------------------------+
//|                                            Phase_DivEngine.mqh   |
//| Pivot scan → regular Div + BOS/INV + HD (visual only)            |
//+------------------------------------------------------------------+
#ifndef PHASE_DIV_ENGINE_MQH
#define PHASE_DIV_ENGINE_MQH

#include "Phase_DivTypes.mqh"
#include "Phase_Divergence.mqh"
#include "Phase_BOS.mqh"

struct SPhDivCfg
  {
   int               pivotLeft;
   int               pivotRight;
   int               minDivBars;
   int               maxDivBars;
   int               minHdBars;
   int               maxHdBars;
   int               bosMaxCandles;
   int               lookback;
   double            deadLow;
   double            deadHigh;
   EPh_BosBreakMode  bosMode;
   bool              showLines;
   bool              showBoxes;
   bool              showBos;
   color             bearClr;
   color             bullClr;
   color             hidBearClr;
   color             hidBullClr;
   color             hidBearBox;
   color             hidBullBox;
   int               lineWidth;
  };

struct SPhDivState
  {
   SPh_Pivot highPivots[];
   SPh_Pivot lowPivots[];
   bool      showHidden;
   int       rsiHandle;
   int       rsiWindow;
  };

void PhDiv_CfgDefault(SPhDivCfg &c)
  {
   c.pivotLeft     = 2;
   c.pivotRight    = 2;
   c.minDivBars    = 3;
   c.maxDivBars    = 100;
   c.minHdBars     = 4;
   c.maxHdBars     = 40;
   c.bosMaxCandles = 50;
   c.lookback      = 400;
   c.deadLow       = 35.0;
   c.deadHigh      = 65.0;
   c.bosMode       = Ph_BOS_CLOSE;
   c.showLines     = true;
   c.showBoxes     = true;
   c.showBos       = true;
   c.bearClr       = clrRed;
   c.bullClr       = clrLime;
   c.hidBearClr    = clrYellow;
   c.hidBullClr    = clrSkyBlue;
   c.hidBearBox    = clrYellow;
   c.hidBullBox    = clrSkyBlue;
   c.lineWidth     = 2;
  }

void PhDiv_StateInit(SPhDivState &st)
  {
   ArrayResize(st.highPivots,0);
   ArrayResize(st.lowPivots,0);
   st.showHidden = true;
   st.rsiHandle  = INVALID_HANDLE;
   st.rsiWindow  = -1;
  }

void PhDiv_OnNewPivotHigh(SPhDivState &st,const SPhDivCfg &cfg,const SPh_Pivot &pivot)
  {
   int size = ArraySize(st.highPivots);
   if(size > 0 && st.highPivots[size - 1].time == pivot.time)
      return;
   ArrayResize(st.highPivots,size + 1);
   st.highPivots[size] = pivot;
   int pos = size;

   SPh_Divergence all[];
   int n = Ph_CollectBearDivergences(st.highPivots,pos,_Symbol,_Period,
                                     cfg.minDivBars,cfg.maxDivBars,
                                     cfg.deadLow,cfg.deadHigh,st.rsiHandle,
                                     cfg.pivotLeft,cfg.pivotRight,all);
   if(n > 0)
     {
      int primary = Ph_PickPrimaryDivIndex(all,n);
      // nearest valid regular only (lambe false HH/LH cut)
      for(int i = 0; i < n; i++)
        {
         if(Ph_IsHiddenBearPattern(all[i].pivotA,all[i].pivotB))
            continue;
         Ph_DrawDivergenceLines(0,st.rsiWindow,all[i],
                                cfg.bearClr,cfg.bullClr,
                                cfg.hidBearClr,cfg.hidBullClr,
                                cfg.lineWidth,cfg.showLines);
         break;
        }
      if(primary >= 0 && cfg.showBos)
        {
         SPh_Divergence bosDiv = all[primary];
         Ph_ApplyChainBos(st.highPivots,pos,_Symbol,_Period,
                          cfg.minDivBars,cfg.maxDivBars,
                          cfg.deadLow,cfg.deadHigh,st.rsiHandle,bosDiv);
         Ph_DrawBos(0,bosDiv,_Period,cfg.bosMaxCandles,cfg.bosMode);
        }
     }

   // HD bear
   SPh_Divergence hid[];
   int nh = Ph_CollectHiddenBearDivergences(st.highPivots,pos,_Symbol,_Period,
                                            cfg.minHdBars,cfg.maxHdBars,
                                            cfg.deadLow,cfg.deadHigh,st.rsiHandle,
                                            cfg.pivotLeft,cfg.pivotRight,hid);
   if(nh > 0 && st.showHidden)
     {
      Ph_DrawDivergenceLines(0,st.rsiWindow,hid[0],
                             cfg.bearClr,cfg.bullClr,
                             cfg.hidBearClr,cfg.hidBullClr,
                             cfg.lineWidth,cfg.showLines);
      Ph_DrawHiddenDivBoxes(0,st.rsiWindow,_Symbol,_Period,hid[0],
                            cfg.hidBearBox,cfg.hidBullBox,cfg.showBoxes);
     }
  }

void PhDiv_OnNewPivotLow(SPhDivState &st,const SPhDivCfg &cfg,const SPh_Pivot &pivot)
  {
   int size = ArraySize(st.lowPivots);
   if(size > 0 && st.lowPivots[size - 1].time == pivot.time)
      return;
   ArrayResize(st.lowPivots,size + 1);
   st.lowPivots[size] = pivot;
   int pos = size;

   SPh_Divergence all[];
   int n = Ph_CollectBullDivergences(st.lowPivots,pos,_Symbol,_Period,
                                     cfg.minDivBars,cfg.maxDivBars,
                                     cfg.deadLow,cfg.deadHigh,st.rsiHandle,
                                     cfg.pivotLeft,cfg.pivotRight,all);
   if(n > 0)
     {
      int primary = Ph_PickPrimaryDivIndex(all,n);
      for(int i = 0; i < n; i++)
        {
         if(Ph_IsHiddenBullPattern(all[i].pivotA,all[i].pivotB))
            continue;
         Ph_DrawDivergenceLines(0,st.rsiWindow,all[i],
                                cfg.bearClr,cfg.bullClr,
                                cfg.hidBearClr,cfg.hidBullClr,
                                cfg.lineWidth,cfg.showLines);
         break;
        }
      if(primary >= 0 && cfg.showBos)
        {
         SPh_Divergence bosDiv = all[primary];
         Ph_ApplyChainBos(st.lowPivots,pos,_Symbol,_Period,
                          cfg.minDivBars,cfg.maxDivBars,
                          cfg.deadLow,cfg.deadHigh,st.rsiHandle,bosDiv);
         Ph_DrawBos(0,bosDiv,_Period,cfg.bosMaxCandles,cfg.bosMode);
        }
     }

   SPh_Divergence hid[];
   int nh = Ph_CollectHiddenBullDivergences(st.lowPivots,pos,_Symbol,_Period,
                                            cfg.minHdBars,cfg.maxHdBars,
                                            cfg.deadLow,cfg.deadHigh,st.rsiHandle,
                                            cfg.pivotLeft,cfg.pivotRight,hid);
   if(nh > 0 && st.showHidden)
     {
      Ph_DrawDivergenceLines(0,st.rsiWindow,hid[0],
                             cfg.bearClr,cfg.bullClr,
                             cfg.hidBearClr,cfg.hidBullClr,
                             cfg.lineWidth,cfg.showLines);
      Ph_DrawHiddenDivBoxes(0,st.rsiWindow,_Symbol,_Period,hid[0],
                            cfg.hidBearBox,cfg.hidBullBox,cfg.showBoxes);
     }
  }

void PhDiv_ProcessBarFromArrays(SPhDivState &st,const SPhDivCfg &cfg,const int shift,
                                const double &highs[],const double &lows[],
                                const double &rsiValues[],const datetime &times[])
  {
   if(shift < cfg.pivotRight + 1)
      return;
   if(shift + cfg.pivotLeft >= ArraySize(highs))
      return;

   if(Ph_FindPivotHigh(shift,highs,cfg.pivotLeft,cfg.pivotRight))
     {
      SPh_Pivot pivot;
      pivot.index = shift;
      pivot.time = times[shift];
      pivot.price = highs[shift];
      pivot.rsiBar = rsiValues[shift];
      pivot.rsi = pivot.rsiBar;
      pivot.rsiTime = pivot.time;
      pivot.candleHigh = highs[shift];
      pivot.candleLow = lows[shift];
      PhDiv_OnNewPivotHigh(st,cfg,pivot);
     }

   if(Ph_FindPivotLow(shift,lows,cfg.pivotLeft,cfg.pivotRight))
     {
      SPh_Pivot pivot;
      pivot.index = shift;
      pivot.time = times[shift];
      pivot.price = lows[shift];
      pivot.rsiBar = rsiValues[shift];
      pivot.rsi = pivot.rsiBar;
      pivot.rsiTime = pivot.time;
      pivot.candleHigh = highs[shift];
      pivot.candleLow = lows[shift];
      PhDiv_OnNewPivotLow(st,cfg,pivot);
     }
  }

void PhDiv_ScanHistory(SPhDivState &st,const SPhDivCfg &cfg)
  {
   if(st.rsiHandle == INVALID_HANDLE)
      return;

   Ph_ClearDivVisuals(0);
   ArrayResize(st.highPivots,0);
   ArrayResize(st.lowPivots,0);

   int bars = Bars(_Symbol,_Period);
   int need = MathMin(cfg.lookback + cfg.pivotLeft + 5,bars);
   if(need < cfg.pivotLeft + cfg.pivotRight + 10)
      return;

   double highs[],lows[],rsiValues[];
   datetime times[];
   if(CopyHigh(_Symbol,_Period,0,need,highs) != need) return;
   if(CopyLow(_Symbol,_Period,0,need,lows) != need) return;
   if(CopyTime(_Symbol,_Period,0,need,times) != need) return;
   if(CopyBuffer(st.rsiHandle,0,0,need,rsiValues) != need) return;
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(rsiValues,true);

   int startShift = need - cfg.pivotLeft - 1;
   for(int shift = startShift; shift >= cfg.pivotRight + 1; shift--)
      PhDiv_ProcessBarFromArrays(st,cfg,shift,highs,lows,rsiValues,times);
  }

void PhDiv_ProcessLiveBar(SPhDivState &st,const SPhDivCfg &cfg)
  {
   if(st.rsiHandle == INVALID_HANDLE)
      return;
   int shift = cfg.pivotRight + 1;
   int need = shift + cfg.pivotLeft + 2;
   double highs[],lows[],rsiValues[];
   datetime times[];
   if(CopyHigh(_Symbol,_Period,0,need,highs) < need) return;
   if(CopyLow(_Symbol,_Period,0,need,lows) < need) return;
   if(CopyTime(_Symbol,_Period,0,need,times) < need) return;
   if(CopyBuffer(st.rsiHandle,0,0,need,rsiValues) < need) return;
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(rsiValues,true);
   PhDiv_ProcessBarFromArrays(st,cfg,shift,highs,lows,rsiValues,times);
  }

void PhDiv_RefreshHiddenVisuals(SPhDivState &st,const SPhDivCfg &cfg)
  {
   Ph_DeleteHiddenObjects(0);
   Ph_UpdateHidButton(0,st.showHidden);
   if(!st.showHidden)
      return;

   datetime drawn[];
   ArrayResize(drawn,0);
   int nh = ArraySize(st.highPivots);
   for(int i = 1; i < nh; i++)
     {
      SPh_Divergence hid[];
      int n = Ph_CollectHiddenBearDivergences(st.highPivots,i,_Symbol,_Period,
                                              cfg.minHdBars,cfg.maxHdBars,
                                              cfg.deadLow,cfg.deadHigh,st.rsiHandle,
                                              cfg.pivotLeft,cfg.pivotRight,hid);
      if(n <= 0) continue;
      datetime key = hid[0].pivotA.time + hid[0].pivotB.time;
      bool skip = false;
      for(int k = 0; k < ArraySize(drawn); k++)
         if(drawn[k] == key) { skip = true; break; }
      if(skip) continue;
      int dn = ArraySize(drawn);
      ArrayResize(drawn,dn + 1);
      drawn[dn] = key;
      Ph_DrawDivergenceLines(0,st.rsiWindow,hid[0],
                             cfg.bearClr,cfg.bullClr,
                             cfg.hidBearClr,cfg.hidBullClr,
                             cfg.lineWidth,cfg.showLines);
      Ph_DrawHiddenDivBoxes(0,st.rsiWindow,_Symbol,_Period,hid[0],
                            cfg.hidBearBox,cfg.hidBullBox,cfg.showBoxes);
     }

   int nl = ArraySize(st.lowPivots);
   for(int i = 1; i < nl; i++)
     {
      SPh_Divergence hid[];
      int n = Ph_CollectHiddenBullDivergences(st.lowPivots,i,_Symbol,_Period,
                                              cfg.minHdBars,cfg.maxHdBars,
                                              cfg.deadLow,cfg.deadHigh,st.rsiHandle,
                                              cfg.pivotLeft,cfg.pivotRight,hid);
      if(n <= 0) continue;
      datetime key = hid[0].pivotA.time + hid[0].pivotB.time;
      bool skip = false;
      for(int k = 0; k < ArraySize(drawn); k++)
         if(drawn[k] == key) { skip = true; break; }
      if(skip) continue;
      int dn = ArraySize(drawn);
      ArrayResize(drawn,dn + 1);
      drawn[dn] = key;
      Ph_DrawDivergenceLines(0,st.rsiWindow,hid[0],
                             cfg.bearClr,cfg.bullClr,
                             cfg.hidBearClr,cfg.hidBullClr,
                             cfg.lineWidth,cfg.showLines);
      Ph_DrawHiddenDivBoxes(0,st.rsiWindow,_Symbol,_Period,hid[0],
                            cfg.hidBearBox,cfg.hidBullBox,cfg.showBoxes);
     }
  }

#endif
//+------------------------------------------------------------------+
