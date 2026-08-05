//+------------------------------------------------------------------+
//|                                            Phase_DivTypes.mqh    |
//| Divergence / BOS / HD shared types (from Future2EA)              |
//+------------------------------------------------------------------+
#ifndef PHASE_DIV_TYPES_MQH
#define PHASE_DIV_TYPES_MQH

enum EPh_BosBreakMode
  {
   Ph_BOS_CLOSE = 0,
   Ph_BOS_WICK  = 1
  };

enum EPh_SeqState
  {
   Ph_SEQ_NONE        = 0,
   Ph_SEQ_BEAR_ACTIVE = 1,
   Ph_SEQ_BULL_ACTIVE = 2
  };

enum EPh_DivType
  {
   Ph_DIV_NONE = 0,
   Ph_DIV_BEAR = -1,
   Ph_DIV_BULL = 1
  };

struct SPh_Pivot
  {
   int      index;
   datetime time;
   double   price;
   double   rsi;      // resolved / candle RSI
   double   rsiBar;   // pivot candle RSI (HD)
   datetime rsiTime;
   double   candleHigh;
   double   candleLow;
  };

struct SPh_Divergence
  {
   bool         valid;
   bool         isHidden;
   EPh_DivType  type;
   SPh_Pivot    pivotA;
   SPh_Pivot    pivotB;
   double       bosLevel;
   datetime     bosTime;
   datetime     detectTime;
  };

#endif
//+------------------------------------------------------------------+
