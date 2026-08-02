# Phase — Tech Context

## Stack
- MQL5 Expert Advisor + custom indicator
- `iRSI(_Symbol, _Period, period, PRICE_CLOSE)`
- Chart objects only (no CCanvas)

## Defaults
| Input | Default |
|-------|---------|
| InpRsiPeriod | 10 |
| InpLookback | 60 |
| InpHistoryBars | 500 |
| InpMinScorePct | 70 |
| Colors | dark green / dark red |

## Paths
- EA: `MQL5/Experts/Phase/Phase.mq5`
- Indicator: `MQL5/Indicators/Phase_RSI.mq5`

## Compile
MetaEditor compile both `Phase.mq5` and `Phase_RSI.mq5`. Indicator must exist before EA attach works.
