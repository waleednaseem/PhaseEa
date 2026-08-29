# Phase — Tech Context

## Stack
- MQL5 Expert Advisor + custom indicator
- `iRSI(_Symbol, _Period, period, PRICE_CLOSE)`
- Chart objects only (no CCanvas)

## Defaults
| Input | Default |
|-------|---------|
| InpRsiPeriod | 14 |
| InpHistoryBars | 500 |
| InpSL_Pips | 800 (FVG 2nd preferred) |
| InpPriceSRBars | 100 |
| Colors | dark green / dark red |

## Paths
- EA: `MQL5/Experts/Phase/Phase.mq5`
- Indicator: `MQL5/Indicators/Phase_RSI.mq5`
- MA: `MQL5/Indicators/Phase_MA.mq5` (SMA 10 white / 100 red)
- FVG SL: `Include/Phase_FVG.mqh` (Future2EA port, no draw)

## Regime walk
- `SPhWalk.loopStep` / `loopPath` / `loopDead` — 0=regular Div; path from Div side; far-cross kills 1/2 until next Div
- AdvanceBar: Div scan before regime step

## Compile
MetaEditor compile `Phase.mq5`, `Phase_RSI.mq5`, and `Phase_MA.mq5`. Indicators must exist before EA attach works.
