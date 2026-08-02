//+------------------------------------------------------------------+
//|                                                       Phase.mq5  |
//| Phase RSI Regime EA — Constance Brown range-shift (visual only)  |
//| Book: Technical Analysis for the Trading Professional (Ch.1)     |
//+------------------------------------------------------------------+
#property copyright "Phase"
#property version   "1.16"

enum ENUM_PH_REGIME
  {
   PH_NEUTRAL = 0,   // range / unknown / transition
   PH_BULLISH = 1,   // RSI holds ~40–80
   PH_BEARISH = 2    // RSI fails ~20–60
  };

input group "=== RSI / CB Zones ==="
input int                InpRsiPeriod      = 14;    // Constance Brown RSI(14)
input ENUM_APPLIED_PRICE InpAppliedPrice   = PRICE_CLOSE;
input int                InpHistoryBars    = 500;
input double             InpBullFloor      = 40.0;  // bull pullback hold (35–50 zone)
input double             InpBullHard       = 35.0;  // leave BUY only below this
input double             InpBearCapLo      = 60.0;  // bear rally fail zone low
input double             InpBearCap        = 65.0;  // leave SELL only above this
input double             InpRsiTol         = 0.5;
input int                InpConfirmBars    = 2;     // bars to confirm breakout/breakdown
input int                InpCapFailCount   = 2;     // 60–65 failures → confirm SELL

input group "=== Display ==="
input bool               InpShowBackground = true;
input bool               InpShowHistory    = true;
input bool               InpShowBoxes      = true;
input bool               InpShowSignals    = true;
input bool               InpAttachRsi      = true;
input color              InpBullColor      = C'12,55,32';
input color              InpBearColor      = C'70,18,22';
input color              InpNeutralColor   = clrBlack;
input color              InpBullBoxColor   = C'0,140,70';
input color              InpBearBoxColor   = C'160,40,45';
input color              InpBuySignalClr   = clrLime;
input color              InpSellSignalClr  = clrRed;
input color              InpEndSignalClr   = clrSilver;

string         g_prefix     = "PH_";
string         g_bgName     = "PH_BG_RECT";
int            g_rsiHandle  = INVALID_HANDLE;
int            g_rsiWindow  = -1;
datetime       g_lastBar    = 0;
ENUM_PH_REGIME g_lastRegime = PH_NEUTRAL;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_rsiHandle = iRSI(_Symbol,_Period,InpRsiPeriod,InpAppliedPrice);
   if(g_rsiHandle == INVALID_HANDLE)
     {
      Print("Phase: iRSI failed");
      return(INIT_FAILED);
     }

   if(InpAttachRsi)
      AttachPhaseRsi();

   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);

   EventSetTimer(1);
   RefreshAll();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteAllPhObjects();
   if(g_rsiHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_rsiHandle);
      g_rsiHandle = INVALID_HANDLE;
     }
   if(InpAttachRsi && g_rsiWindow >= 0)
     {
      int total = ChartIndicatorsTotal(0,g_rsiWindow);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ChartIndicatorName(0,g_rsiWindow,i);
         if(StringFind(name,"Phase_RSI") == 0)
            ChartIndicatorDelete(0,g_rsiWindow,name);
        }
     }
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime t = iTime(_Symbol,_Period,0);
   if(t == 0 || t == g_lastBar)
      return;
   g_lastBar = t;
   RefreshAll();
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   if(InpShowBackground && ObjectFind(0,g_bgName) >= 0)
     {
      ObjectSetInteger(0,g_bgName,OBJPROP_XSIZE,(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS));
      ObjectSetInteger(0,g_bgName,OBJPROP_YSIZE,(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS));
     }
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE && InpShowBackground && ObjectFind(0,g_bgName) >= 0)
     {
      ObjectSetInteger(0,g_bgName,OBJPROP_XSIZE,(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS));
      ObjectSetInteger(0,g_bgName,OBJPROP_YSIZE,(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS));
     }
  }

//+------------------------------------------------------------------+
void AttachPhaseRsi()
  {
   // remove any old Phase_RSI so period/levels match EA inputs
   int wins = (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL);
   for(int w = wins - 1; w >= 0; w--)
     {
      int n = ChartIndicatorsTotal(0,w);
      for(int i = n - 1; i >= 0; i--)
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
      Print("Phase: Phase_RSI not found — compile Indicators/Phase_RSI.mq5 first");
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

//+------------------------------------------------------------------+
void RefreshAll()
  {
   int bars = Bars(_Symbol,_Period);
   int need = InpHistoryBars + 20;
   if(need > bars)
      need = bars;
   if(need < 30)
      return;

   double rsi[];
   ArraySetAsSeries(rsi,true);
   if(CopyBuffer(g_rsiHandle,0,0,need,rsi) < 30)
      return;

   int hist = MathMin(InpHistoryBars,ArraySize(rsi) - 2);
   if(hist < 5)
      return;

   // skip invalid RSI warmup bars
   for(int i = 0; i < ArraySize(rsi); i++)
     {
      if(rsi[i] == EMPTY_VALUE || rsi[i] < 0.0 || rsi[i] > 100.0)
         rsi[i] = 50.0;
     }

   ENUM_PH_REGIME regimes[];
   ArrayResize(regimes,hist + 1);
   ArrayInitialize(regimes,(int)PH_NEUTRAL);

   BuildCbRegimes(rsi,hist,regimes);

   g_lastRegime = regimes[1];
   UpdateBackground(g_lastRegime);

   if(InpShowHistory)
      PaintHistoryStrips(regimes,hist);

   if(InpShowBoxes)
      PaintBodyBoxes(regimes,hist);

   if(InpShowSignals)
      PaintRegimeSignals(regimes,hist);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
// Constance Brown Ch.1 range-shift (sticky overlap):
//
//   BULL band ≈ 35–80 : pullbacks hold 35/40/50, advances into 80s
//   BEAR band ≈ 20–65 : rallies fail 50/60/65, declines into 20s
//   Overlap   ≈ 35–65 : DO NOT FLIP — previous regime continues
//
//   Leave BUY  → only sustained close < 35
//   Leave SELL → only sustained close > 65
//   Cap fails (tag 60–65 then reject) → confirm/enter SELL
//   Floor holds after >65 breakout → confirm BUY
//   RSI @ 80 = bull ceiling, NEVER a sell signal
void BuildCbRegimes(const double &rsi[],const int hist,ENUM_PH_REGIME &regimes[])
  {
   const double floor   = InpBullFloor;     // 40
   const double hard    = InpBullHard;      // 35
   const double capLo   = InpBearCapLo;     // 60
   const double cap     = InpBearCap;       // 65
   const double tol     = InpRsiTol;
   const int    need    = MathMax(1,InpConfirmBars);
   const int    needFail= MathMax(1,InpCapFailCount);

   ENUM_PH_REGIME state = PH_NEUTRAL;
   int  belowHard = 0;
   int  aboveCap  = 0;
   int  capFails  = 0;
   int  floorHolds= 0;
   bool taggedCap = false;
   bool taggedFloor = false;
   bool hadBreakout = false;  // saw close >65 in this bull attempt

   for(int shift = hist; shift >= 1; shift--)
     {
      double v = rsi[shift];
      double vOlder = (shift + 1 <= hist ? rsi[shift + 1] : v);

      // --- bear-cap failure: tag 60–65 then close back below 60 ---
      if(v >= capLo - tol && v <= cap + tol)
         taggedCap = true;
      if(taggedCap && v < capLo - tol)
        {
         capFails++;
         taggedCap = false;
        }
      if(v > cap + tol)
        {
         taggedCap = false;
         capFails = 0;       // true breakout cancels fail count
         hadBreakout = true;
        }

      // --- bull-floor hold: tag 35–50 then rise back ---
      if(v >= hard - tol && v <= floor + 10.0 + tol)  // 35–50 zone
         taggedFloor = true;
      if(taggedFloor && v > floor + tol && v > vOlder)
        {
         floorHolds++;
         taggedFloor = false;
        }
      if(v < hard - tol)
        {
         taggedFloor = false;
         floorHolds = 0;
         hadBreakout = false;
        }

      // ========== BULL: sticky until <35 ==========
      if(state == PH_BULLISH)
        {
         aboveCap = 0;
         // overlap + up to 80 = stay BUY (incl. RSI@80)
         if(v >= hard - tol)
            belowHard = 0;
         else
           {
            belowHard++;
            if(belowHard >= need)
              {
               state = PH_BEARISH;
               belowHard = 0;
               capFails = 0;
               floorHolds = 0;
               hadBreakout = false;
              }
           }
        }
      // ========== BEAR: sticky until >65 ==========
      else if(state == PH_BEARISH)
        {
         belowHard = 0;
         floorHolds = 0;
         // entire 20–65 band = stay SELL (60–65 bounces included)
         if(v > cap + tol)
           {
            aboveCap++;
            if(aboveCap >= need)
              {
               state = PH_BULLISH;
               aboveCap = 0;
               capFails = 0;
               hadBreakout = true;
              }
           }
         else
            aboveCap = 0;
        }
      // ========== NEUTRAL: seed from extremes / cap fails ==========
      else
        {
         if(v > cap + tol)
           {
            aboveCap++;
            belowHard = 0;
            if(aboveCap >= need)
              {
               state = PH_BULLISH;
               aboveCap = 0;
               capFails = 0;
               hadBreakout = true;
              }
           }
         else if(v < hard - tol)
           {
            belowHard++;
            aboveCap = 0;
            if(belowHard >= need)
              {
               state = PH_BEARISH;
               belowHard = 0;
               floorHolds = 0;
               hadBreakout = false;
              }
           }
         else if(capFails >= needFail)
           {
            // repeated 60–65 failures → SELL regime
            state = PH_BEARISH;
            capFails = 0;
            aboveCap = 0;
            belowHard = 0;
            hadBreakout = false;
           }
         else if(hadBreakout && floorHolds >= needFail)
           {
            // broke >65 then held 35–50 → BUY
            state = PH_BULLISH;
            floorHolds = 0;
            aboveCap = 0;
            belowHard = 0;
           }
         else
           {
            aboveCap = 0;
            belowHard = 0;
           }
        }

      regimes[shift] = state;
     }
  }

//+------------------------------------------------------------------+
color RegimeColor(const ENUM_PH_REGIME r)
  {
   if(r == PH_BULLISH)
      return InpBullColor;
   if(r == PH_BEARISH)
      return InpBearColor;
   return InpNeutralColor;
  }

//+------------------------------------------------------------------+
void UpdateBackground(const ENUM_PH_REGIME r)
  {
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   if(!InpShowBackground)
     {
      ObjectDelete(0,g_bgName);
      return;
     }
   if(ObjectFind(0,g_bgName) < 0)
     {
      ObjectCreate(0,g_bgName,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,g_bgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,g_bgName,OBJPROP_XDISTANCE,0);
      ObjectSetInteger(0,g_bgName,OBJPROP_YDISTANCE,0);
      ObjectSetInteger(0,g_bgName,OBJPROP_BACK,true);
      ObjectSetInteger(0,g_bgName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,g_bgName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,g_bgName,OBJPROP_ZORDER,0);
     }
   ObjectSetInteger(0,g_bgName,OBJPROP_XSIZE,(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS));
   ObjectSetInteger(0,g_bgName,OBJPROP_YSIZE,(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS));
   ObjectSetInteger(0,g_bgName,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(0,g_bgName,OBJPROP_COLOR,clrBlack);
  }

//+------------------------------------------------------------------+
void DeleteByPrefix(const string prefix)
  {
   int total = ObjectsTotal(0,-1,-1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0,i,-1,-1);
      if(StringFind(name,prefix) == 0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
void DeleteAllPhObjects()
  {
   DeleteByPrefix(g_prefix);
  }

//+------------------------------------------------------------------+
void PaintHistoryStrips(const ENUM_PH_REGIME &regimes[],const int hist)
  {
   DeleteByPrefix(g_prefix + "HS_");

   datetime times[];
   double   highs[], lows[];
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   if(CopyTime(_Symbol,_Period,0,hist + 2,times) < hist + 1)
      return;
   if(CopyHigh(_Symbol,_Period,0,hist + 2,highs) < hist + 1)
      return;
   if(CopyLow(_Symbol,_Period,0,hist + 2,lows) < hist + 1)
      return;

   int segNewer = 1;
   ENUM_PH_REGIME segReg = regimes[1];
   for(int shift = 2; shift <= hist; shift++)
     {
      if(regimes[shift] == segReg)
         continue;
      if(segReg != PH_NEUTRAL)
         DrawStrip(segNewer,shift - 1,segReg,times,highs,lows);
      segNewer = shift;
      segReg = regimes[shift];
     }
   if(segReg != PH_NEUTRAL)
      DrawStrip(segNewer,hist,segReg,times,highs,lows);
  }

//+------------------------------------------------------------------+
void DrawStrip(const int shiftNewer,const int shiftOlder,const ENUM_PH_REGIME r,
               const datetime &times[],const double &highs[],const double &lows[])
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
   hi += pad;
   lo -= pad;

   string name = g_prefix + "HS_" + IntegerToString((int)tLeft);
   ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,tLeft,hi,tRight,lo))
      return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,RegimeColor(r));
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
void PaintBodyBoxes(const ENUM_PH_REGIME &regimes[],const int hist)
  {
   DeleteByPrefix(g_prefix + "BX_");

   datetime times[];
   double   opens[], closes[];
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(opens,true);
   ArraySetAsSeries(closes,true);
   if(CopyTime(_Symbol,_Period,0,hist + 2,times) < hist)
      return;
   if(CopyOpen(_Symbol,_Period,0,hist + 2,opens) < hist)
      return;
   if(CopyClose(_Symbol,_Period,0,hist + 2,closes) < hist)
      return;

   for(int shift = 1; shift < hist; shift++)
     {
      ENUM_PH_REGIME r = regimes[shift];
      if(r != PH_BULLISH && r != PH_BEARISH)
         continue;

      bool upNow   = (closes[shift] > opens[shift]);
      bool downNow = (closes[shift] < opens[shift]);
      bool upPrev  = (closes[shift + 1] > opens[shift + 1]);
      bool downPrev= (closes[shift + 1] < opens[shift + 1]);

      bool draw = false;
      color boxClr = InpBullBoxColor;
      if(r == PH_BULLISH && downPrev && upNow)
        {
         draw = true;
         boxClr = InpBullBoxColor;
        }
      else if(r == PH_BEARISH && upPrev && downNow)
        {
         draw = true;
         boxClr = InpBearBoxColor;
        }
      if(!draw)
         continue;

      double y1 = opens[shift];
      double y2 = closes[shift];
      datetime t1 = times[shift];
      datetime t2 = times[shift];
      int sec = PeriodSeconds(_Period);
      t1 = t1 - sec / 4;
      t2 = t2 + sec / 4;

      string name = g_prefix + "BX_" + IntegerToString((int)times[shift]);
      if(ObjectFind(0,name) >= 0)
         ObjectDelete(0,name);
      if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,y1,t2,y2))
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

//+------------------------------------------------------------------+
// BUY = bull confirm | SELL = bear confirm | END = leave bull/bear
void PaintRegimeSignals(const ENUM_PH_REGIME &regimes[],const int hist)
  {
   DeleteByPrefix(g_prefix + "SG_");

   datetime times[];
   double   highs[], lows[];
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   if(CopyTime(_Symbol,_Period,0,hist + 2,times) < hist + 1)
      return;
   if(CopyHigh(_Symbol,_Period,0,hist + 2,highs) < hist + 1)
      return;
   if(CopyLow(_Symbol,_Period,0,hist + 2,lows) < hist + 1)
      return;

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
      bool buyEnd    = (older == PH_BULLISH && cur != PH_BULLISH);
      bool sellStart = (cur == PH_BEARISH && older != PH_BEARISH);
      bool sellEnd   = (older == PH_BEARISH && cur != PH_BEARISH);

      if(buyStart)
         DrawSignalArrow(g_prefix + "SG_BUY_" + id,t,lows[shift] - pad,
                         InpBuySignalClr,233,ANCHOR_TOP,"BUY");

      if(buyEnd)
         DrawSignalArrow(g_prefix + "SG_END_B_" + id,t,
                         highs[shift] + pad * (sellStart ? 1.8 : 1.0),
                         InpEndSignalClr,251,ANCHOR_BOTTOM,"END");

      if(sellStart)
         DrawSignalArrow(g_prefix + "SG_SELL_" + id,t,highs[shift] + pad,
                         InpSellSignalClr,234,ANCHOR_BOTTOM,"SELL");

      if(sellEnd)
         DrawSignalArrow(g_prefix + "SG_END_S_" + id,t,
                         lows[shift] - pad * (buyStart ? 1.8 : 1.0),
                         InpEndSignalClr,251,ANCHOR_TOP,"END");
     }
  }

//+------------------------------------------------------------------+
void DrawSignalArrow(const string name,const datetime t,const double price,
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
//+------------------------------------------------------------------+
