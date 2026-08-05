//+------------------------------------------------------------------+
//|                                              Phase_Draw.mqh      |
//+------------------------------------------------------------------+
#ifndef PHASE_DRAW_MQH
#define PHASE_DRAW_MQH

#include "Phase_Types.mqh"

string g_phPrefix = "PH_";
string g_phBgName = "PH_BG_RECT";

color PhRegimeColor(const ENUM_PH_REGIME r,
                    const color bullClr,const color bearClr,const color neuClr)
  {
   if(r == PH_BULLISH) return bullClr;
   if(r == PH_BEARISH) return bearClr;
   return neuClr;
  }

void PhDeleteByPrefix(const string prefix)
  {
   int total = ObjectsTotal(0,-1,-1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0,i,-1,-1);
      if(StringFind(name,prefix) == 0)
         ObjectDelete(0,name);
     }
  }

void PhDeleteAll()
  {
   PhDeleteByPrefix(g_phPrefix);
  }

void PhResizeBg()
  {
   if(ObjectFind(0,g_phBgName) < 0)
      return;
   ObjectSetInteger(0,g_phBgName,OBJPROP_XSIZE,(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS));
   ObjectSetInteger(0,g_phBgName,OBJPROP_YSIZE,(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS));
  }

void PhUpdateBackground(const bool show,const ENUM_PH_REGIME /*r*/)
  {
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   if(!show)
     {
      ObjectDelete(0,g_phBgName);
      return;
     }
   if(ObjectFind(0,g_phBgName) < 0)
     {
      ObjectCreate(0,g_phBgName,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,g_phBgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,g_phBgName,OBJPROP_XDISTANCE,0);
      ObjectSetInteger(0,g_phBgName,OBJPROP_YDISTANCE,0);
      ObjectSetInteger(0,g_phBgName,OBJPROP_BACK,true);
      ObjectSetInteger(0,g_phBgName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,g_phBgName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,g_phBgName,OBJPROP_ZORDER,0);
     }
   PhResizeBg();
   ObjectSetInteger(0,g_phBgName,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(0,g_phBgName,OBJPROP_COLOR,clrBlack);
  }

void PhDrawStrip(const int shiftNewer,const int shiftOlder,const ENUM_PH_REGIME r,
                 const datetime &times[],const double &highs[],const double &lows[],
                 const color bullClr,const color bearClr,const color neuClr)
  {
   if(shiftNewer < 1 || shiftOlder < 1 || shiftNewer > shiftOlder)
      return;
   if(shiftOlder >= ArraySize(times))
      return;

   datetime tLeft  = times[shiftOlder];
   datetime tRight = times[shiftNewer] + PeriodSeconds(_Period) / 2;
   if(tRight <= tLeft)
      tRight = tLeft + PeriodSeconds(_Period);

   double hi = highs[shiftNewer];
   double lo = lows[shiftNewer];
   for(int s = shiftNewer; s <= shiftOlder; s++)
     {
      if(highs[s] > hi) hi = highs[s];
      if(lows[s]  < lo) lo = lows[s];
     }
   double pad = (hi - lo) * 0.15;
   if(pad <= 0.0)
      pad = _Point * 50.0;

   string name = g_phPrefix + "HS_" + IntegerToString((int)tLeft);
   ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,tLeft,hi + pad,tRight,lo - pad))
      return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,PhRegimeColor(r,bullClr,bearClr,neuClr));
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void PhPaintHistory(const ENUM_PH_REGIME &regimes[],const int hist,
                    const color bullClr,const color bearClr,const color neuClr)
  {
   PhDeleteByPrefix(g_phPrefix + "HS_");

   datetime times[];
   double   highs[], lows[];
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   if(CopyTime(_Symbol,_Period,0,hist + 2,times) < hist + 1) return;
   if(CopyHigh(_Symbol,_Period,0,hist + 2,highs) < hist + 1) return;
   if(CopyLow(_Symbol,_Period,0,hist + 2,lows) < hist + 1) return;

   int segNewer = 1;
   ENUM_PH_REGIME segReg = regimes[1];
   for(int shift = 2; shift <= hist; shift++)
     {
      if(regimes[shift] == segReg)
         continue;
      if(segReg != PH_NEUTRAL)
         PhDrawStrip(segNewer,shift - 1,segReg,times,highs,lows,bullClr,bearClr,neuClr);
      segNewer = shift;
      segReg = regimes[shift];
     }
   if(segReg != PH_NEUTRAL)
      PhDrawStrip(segNewer,hist,segReg,times,highs,lows,bullClr,bearClr,neuClr);
  }

void PhPaintBoxes(const ENUM_PH_REGIME &regimes[],const int hist,
                  const color bullBox,const color bearBox)
  {
   PhDeleteByPrefix(g_phPrefix + "BX_");

   datetime times[];
   double   opens[], closes[];
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(opens,true);
   ArraySetAsSeries(closes,true);
   if(CopyTime(_Symbol,_Period,0,hist + 2,times) < hist) return;
   if(CopyOpen(_Symbol,_Period,0,hist + 2,opens) < hist) return;
   if(CopyClose(_Symbol,_Period,0,hist + 2,closes) < hist) return;

   const int sec = PeriodSeconds(_Period);
   for(int shift = 1; shift < hist; shift++)
     {
      ENUM_PH_REGIME r = regimes[shift];
      if(r != PH_BULLISH && r != PH_BEARISH)
         continue;

      const bool upNow    = (closes[shift] > opens[shift]);
      const bool downNow  = (closes[shift] < opens[shift]);
      const bool upPrev   = (closes[shift + 1] > opens[shift + 1]);
      const bool downPrev = (closes[shift + 1] < opens[shift + 1]);

      color boxClr = bullBox;
      bool  draw   = false;
      if(r == PH_BULLISH && downPrev && upNow)
        { draw = true; boxClr = bullBox; }
      else if(r == PH_BEARISH && upPrev && downNow)
        { draw = true; boxClr = bearBox; }
      if(!draw)
         continue;

      datetime t1 = times[shift] - sec / 4;
      datetime t2 = times[shift] + sec / 4;
      string name = g_phPrefix + "BX_" + IntegerToString((int)times[shift]);
      ObjectDelete(0,name);
      if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,opens[shift],t2,closes[shift]))
         continue;
      ObjectSetInteger(0,name,OBJPROP_COLOR,boxClr);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_FILL,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }
  }

void PhDrawSignal(const string name,const datetime t,const double price,
                  const color clr,const int arrowCode,const ENUM_ARROW_ANCHOR anch,
                  const string label)
  {
   ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_ARROW,0,t,price))
      return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,arrowCode);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anch);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);

   string txt = name + "_T";
   ObjectDelete(0,txt);
   if(!ObjectCreate(0,txt,OBJ_TEXT,0,t,price))
      return;
   ObjectSetString(0,txt,OBJPROP_TEXT," " + label);
   ObjectSetInteger(0,txt,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,txt,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,txt,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,txt,OBJPROP_ANCHOR,anch);
   ObjectSetInteger(0,txt,OBJPROP_BACK,false);
   ObjectSetInteger(0,txt,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,txt,OBJPROP_HIDDEN,true);
  }

void PhPaintSignals(const ENUM_PH_REGIME &regimes[],const int hist,
                    const color buyClr,const color sellClr)
  {
   PhDeleteByPrefix(g_phPrefix + "SG_");

   datetime times[];
   double   highs[], lows[];
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   if(CopyTime(_Symbol,_Period,0,hist + 2,times) < hist + 1) return;
   if(CopyHigh(_Symbol,_Period,0,hist + 2,highs) < hist + 1) return;
   if(CopyLow(_Symbol,_Period,0,hist + 2,lows) < hist + 1) return;

   double sum = 0.0;
   int n = MathMin(14,hist);
   for(int i = 1; i <= n; i++)
      sum += (highs[i] - lows[i]);
   double pad = (n > 0 ? sum / n : _Point * 100.0) * 0.5;
   if(pad <= 0.0)
      pad = _Point * 50.0;

   for(int shift = hist - 1; shift >= 1; shift--)
     {
      ENUM_PH_REGIME cur   = regimes[shift];
      ENUM_PH_REGIME older = regimes[shift + 1];
      if(cur == older)
         continue;

      datetime t  = times[shift];
      string   id = IntegerToString((int)t);
      bool buyStart  = (cur == PH_BULLISH && older != PH_BULLISH);
      bool sellStart = (cur == PH_BEARISH && older != PH_BEARISH);

      if(buyStart)
         PhDrawSignal(g_phPrefix + "SG_BUY_" + id,t,lows[shift] - pad,
                      buyClr,233,ANCHOR_TOP,"BUY");
      if(sellStart)
         PhDrawSignal(g_phPrefix + "SG_SELL_" + id,t,highs[shift] + pad,
                      sellClr,234,ANCHOR_BOTTOM,"SELL");
     }
  }

void PhPaintRsiSR(const SPhSRList &L,const int rsiWindow,
                  const color supClr,const color resClr)
  {
   PhDeleteByPrefix(g_phPrefix + "SR_");
   if(rsiWindow < 0 || L.count <= 0)
      return;

   for(int i = 0; i < L.count; i++)
     {
      const SPhSRSeg s = L.seg[i];
      if(s.t1 <= s.t0)
         continue;
      string name = g_phPrefix + "SR_" + IntegerToString(i) +
                    (s.isSupport ? "_S" : "_R");
      ObjectDelete(0,name);
      if(!ObjectCreate(0,name,OBJ_TREND,rsiWindow,s.t0,s.level0,s.t1,s.level1))
         continue;
      ObjectSetInteger(0,name,OBJPROP_COLOR,s.isSupport ? supClr : resClr);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }
  }

#endif
//+------------------------------------------------------------------+
