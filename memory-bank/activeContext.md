# Phase — Active Context

## Current focus
v1.10: CB sticky range-shift (40 floor / 65 cap). Recompile Phase.mq5 + Phase_RSI.mq5, re-attach.

## Decisions
- RSI(14); bull floor 40; bear cap 65
- RSI@80 = bull ceiling → BUY regime, NOT sell
- SELL only after RSI breaks below 40 + fail under 65
- BUY only after RSI breaks above 65 + hold above 40
- Chart bg black; colors on strips/boxes/signals
- Object prefix `PH_`
