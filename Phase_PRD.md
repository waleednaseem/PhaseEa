# Phase RSI Regime EA — PRD v1.2

## Goal
Visual EA: Constance Brown RSI **range-shift** regimes. **No trading.**

## Source
Brown, *Technical Analysis for the Trading Professional* Ch.1 (+ project `ConstanceBrown_PRD.md`)

## RSI
- Period: **14**
- Zones: bull floor **40**, bear cap **65** (tol ±1)
- Companion: `Phase_RSI` — fills bull floor 40–50 / bear cap 55–65

## Regime (sticky state machine) — default Neutral
**Bull (green):** RSI breaks **above 65**, then holds **≥40**
- Pullbacks live ~40–50; advances into ~80s are still **bull** (not sell)

**Bear (red):** RSI breaks **below 40**, then stays **≤65**
- Rallies fail ~55–65; declines into ~20s

**End:** leave bull on close &lt;40 → grey END; leave bear on close &gt;65 → grey END

## Signals
- Bull confirm → green **BUY**
- Bear confirm → red **SELL**
- Regime leave → grey **END**

## History / boxes
- Last 500 bars colored strips + continuation body boxes

## Non-goals
No orders / Docker / sibling EA edits
