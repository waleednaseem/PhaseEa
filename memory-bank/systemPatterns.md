# Phase — System Patterns

## Layout
```
Experts/Phase/
  Phase.mq5          # orchestrator EA
  Phase_PRD.md
  memory-bank/
Indicators/Phase_RSI.mq5
```

## Flow
OnInit → iRSI + ChartIndicatorAdd(Phase_RSI) → OnTick new bar → CopyBuffer → ScoreRegime → UpdateBg / PaintHistory / PaintBoxes

## Drawing
- Full bg: `OBJ_RECTANGLE_LABEL` (CB_RSI_Regime pattern)
- History: `OBJ_RECTANGLE` fill back, time-based segments
- Boxes: `OBJ_RECTANGLE` open–close only, prefix `PH_`
- Cleanup: delete all `PH_*` on deinit

## Naming
- Inputs: `Inp*`
- Globals: `g_*`
- Objects: `PH_`
