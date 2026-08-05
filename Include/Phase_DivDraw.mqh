//+------------------------------------------------------------------+
//|                                             Phase_DivDraw.mqh    |
//| Div/BOS/HD chart helpers (no F2E dashboard)                      |
//+------------------------------------------------------------------+
#ifndef PHASE_DIV_DRAW_MQH
#define PHASE_DIV_DRAW_MQH

#include "Phase_DivTypes.mqh"

string g_phDivPrefix = "PH_";

string Ph_BuildId(const string type,const datetime t1,const datetime t2=0)
  {
   if(t2 > 0)
      return(g_phDivPrefix + type + "_" + StringFormat("%I64d",(long)t1) + "_" + StringFormat("%I64d",(long)t2));
   return(g_phDivPrefix + type + "_" + StringFormat("%I64d",(long)t1));
  }

int Ph_PeriodSeconds(const ENUM_TIMEFRAMES tf)
  {
   int s = PeriodSeconds(tf);
   if(s <= 0) s = 60;
   return(s);
  }

void Ph_DrawTrend(const long chartId,const string name,const int subwindow,
                  const datetime t1,const double p1,const datetime t2,const double p2,
                  const color clr,const int width)
  {
   if(ObjectFind(chartId,name) < 0)
      ObjectCreate(chartId,name,OBJ_TREND,subwindow,t1,p1,t2,p2);
   else
     {
      ObjectMove(chartId,name,0,t1,p1);
      ObjectMove(chartId,name,1,t2,p2);
     }
   ObjectSetInteger(chartId,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(chartId,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(chartId,name,OBJPROP_BACK,false);
   ObjectSetInteger(chartId,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(chartId,name,OBJPROP_HIDDEN,true);
  }

void Ph_DrawBosLine(const long chartId,const string name,const datetime fromTime,
                    const datetime endTime,const double level,const ENUM_TIMEFRAMES tf,
                    const color clr=clrWhite)
  {
   datetime t1 = fromTime;
   datetime t2 = endTime;
   if(t2 <= t1)
      t2 = t1 + Ph_PeriodSeconds(tf);

   if(ObjectFind(chartId,name) < 0)
      ObjectCreate(chartId,name,OBJ_TREND,0,t1,level,t2,level);
   else
     {
      ObjectMove(chartId,name,0,t1,level);
      ObjectMove(chartId,name,1,t2,level);
     }
   ObjectSetInteger(chartId,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(chartId,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(chartId,name,OBJPROP_BACK,false);
   ObjectSetInteger(chartId,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(chartId,name,OBJPROP_HIDDEN,false);

   string labelName = name + "_Lbl";
   if(ObjectFind(chartId,labelName) < 0)
      ObjectCreate(chartId,labelName,OBJ_TEXT,0,t1,level);
   else
      ObjectMove(chartId,labelName,0,t1,level);
   ObjectSetString(chartId,labelName,OBJPROP_TEXT,"Break of Structure (BOS)");
   ObjectSetInteger(chartId,labelName,OBJPROP_COLOR,clr);
   ObjectSetInteger(chartId,labelName,OBJPROP_FONTSIZE,8);
   ObjectSetString(chartId,labelName,OBJPROP_FONT,"Arial");
   ObjectSetInteger(chartId,labelName,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
   ObjectSetInteger(chartId,labelName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(chartId,labelName,OBJPROP_HIDDEN,false);
  }

void Ph_DrawRect(const long chartId,const string name,const int subwindow,
                 const datetime t1,const double top,const datetime t2,const double bottom,
                 const color clr,const int width=1)
  {
   if(ObjectFind(chartId,name) < 0)
      ObjectCreate(chartId,name,OBJ_RECTANGLE,subwindow,t1,top,t2,bottom);
   else
     {
      ObjectMove(chartId,name,0,t1,top);
      ObjectMove(chartId,name,1,t2,bottom);
     }
   ObjectSetInteger(chartId,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(chartId,name,OBJPROP_FILL,false);
   ObjectSetInteger(chartId,name,OBJPROP_BACK,false);
   ObjectSetInteger(chartId,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(chartId,name,OBJPROP_HIDDEN,true);
  }

void Ph_DrawSignalBox(const long chartId,const int rsiSubwindow,
                      const string symbol,const ENUM_TIMEFRAMES tf,
                      const int shift,const double rsiVal,const color clr,
                      const bool show,const string tagPrefix)
  {
   if(!show || shift < 0)
      return;
   datetime t = iTime(symbol,tf,shift);
   if(t <= 0)
      return;
   int sec = Ph_PeriodSeconds(tf);
   datetime t1 = t - sec / 4;
   datetime t2 = t + sec / 4;
   double hi = iHigh(symbol,tf,shift);
   double lo = iLow(symbol,tf,shift);
   string priceName = Ph_BuildId(tagPrefix + "P",t);
   string rsiName   = Ph_BuildId(tagPrefix + "R",t);
   Ph_DrawRect(chartId,priceName,0,t1,hi,t2,lo,clr,1);
   if(rsiSubwindow >= 0 && rsiVal > 0.0)
     {
      double pad = 1.5;
      Ph_DrawRect(chartId,rsiName,rsiSubwindow,t1,rsiVal + pad,t2,rsiVal - pad,clr,1);
     }
  }

void Ph_DrawHiddenPivotBox(const long chartId,const int rsiSubwindow,
                           const string symbol,const ENUM_TIMEFRAMES tf,
                           const SPh_Pivot &pivot,const color clr,const bool show)
  {
   if(!show)
      return;
   int shift = iBarShift(symbol,tf,pivot.time,false);
   if(shift < 0)
      return;
   Ph_DrawSignalBox(chartId,rsiSubwindow,symbol,tf,shift,pivot.rsi,clr,true,"HidBox");
  }

void Ph_DrawHiddenDivBoxes(const long chartId,const int rsiSubwindow,
                           const string symbol,const ENUM_TIMEFRAMES tf,
                           const SPh_Divergence &div,
                           const color hidBearClr,const color hidBullClr,
                           const bool show)
  {
   if(!show || !div.valid || !div.isHidden)
      return;
   color clr = (div.type == Ph_DIV_BEAR) ? hidBearClr : hidBullClr;
   Ph_DrawHiddenPivotBox(chartId,rsiSubwindow,symbol,tf,div.pivotB,clr,show);
  }

string Ph_HidBtnName()
  {
   return(g_phDivPrefix + "BtnHidDiv");
  }

void Ph_DeleteByDivTag(const long chartId,const string tag)
  {
   int total = ObjectsTotal(chartId,-1,-1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(chartId,i,-1,-1);
      if(StringFind(name,tag) == 0)
         ObjectDelete(chartId,name);
     }
  }

void Ph_DeleteHiddenObjects(const long chartId=0)
  {
   Ph_DeleteByDivTag(chartId,g_phDivPrefix + "Hid");
  }

// Full Div/BOS/INV wipe (HD button keep)
void Ph_ClearDivVisuals(const long chartId=0)
  {
   Ph_DeleteByDivTag(chartId,g_phDivPrefix + "BearDiv");
   Ph_DeleteByDivTag(chartId,g_phDivPrefix + "BullDiv");
   Ph_DeleteByDivTag(chartId,g_phDivPrefix + "Hid");
   Ph_DeleteByDivTag(chartId,g_phDivPrefix + "BOS_");
   Ph_DeleteByDivTag(chartId,g_phDivPrefix + "INV_");
  }

void Ph_UpdateHidButton(const long chartId,const bool showHid,
                        const int x=12,const int y=18)
  {
   string name = Ph_HidBtnName();
   if(ObjectFind(chartId,name) < 0)
      ObjectCreate(chartId,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(chartId,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chartId,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(chartId,name,OBJPROP_XSIZE,90);
   ObjectSetInteger(chartId,name,OBJPROP_YSIZE,22);
   ObjectSetInteger(chartId,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(chartId,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(chartId,name,OBJPROP_ZORDER,100);
   ObjectSetString(chartId,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(chartId,name,OBJPROP_FONTSIZE,9);
   if(showHid)
     {
      ObjectSetString(chartId,name,OBJPROP_TEXT,"HD: ON");
      ObjectSetInteger(chartId,name,OBJPROP_BGCOLOR,clrDarkSlateGray);
      ObjectSetInteger(chartId,name,OBJPROP_COLOR,clrSkyBlue);
     }
   else
     {
      ObjectSetString(chartId,name,OBJPROP_TEXT,"HD: OFF");
      ObjectSetInteger(chartId,name,OBJPROP_BGCOLOR,clrDimGray);
      ObjectSetInteger(chartId,name,OBJPROP_COLOR,clrWhite);
     }
   ObjectSetInteger(chartId,name,OBJPROP_STATE,false);
  }

#endif
//+------------------------------------------------------------------+
