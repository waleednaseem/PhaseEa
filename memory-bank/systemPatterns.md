# Phase — System Patterns

## Layout
```
Experts/Phase/
  Phase.mq5
  Include/
    Phase_Types.mqh
    Phase_SR.mqh
    Phase_PriceSR.mqh      # last-100 price swing bounce/reject
    Phase_FVG.mqh          # detect + 2nd/3rd dyn SL (no draw)
    Phase_BuyRegime.mqh
    Phase_SellRegime.mqh
    Phase_Regime.mqh
    Phase_Draw.mqh
    Phase_Dash.mqh
    Phase_DivEngine.mqh
    Phase_Trade.mqh
```

## 0-1-2 loop
**0** = regular Div pivot only (not inside 35-40 / 60-65). New Div while at 1 = restart 0, never auto-2.
**Path from Div RSI:** `<35` → 1 at 59-65 reject (or 65 sharp-down) → 2 at 35-41 bounce (or 35 sharp-up) → BUY. `>65` → 1 at 35-41 → 2 at 59-65 → SELL.
Far-side close through (div-low then 65 / div-high then 35) without sharp reverse ≤3 bars → `loopDead` until next regular Div (no 1/2).
1 and 2 never both in the same bounce band. PriceSR sharp only if RSI already in that band.

## Flow
OnInit → IgniteHistory → freeze g_regimes + g_walk
OnTick new bar → RunDivScan → PhRegimeAdvance → regime CloseAll if flip → bounce + PriceSR → paint → Div exits/unlock → HD entries

## Conventions
- Config: `g_cfg` loaded once
- No full 500-bar re-walk after ignite
- INV never at/near 35/65; S&R stops on regime END
- Objects: prefix `PH_`; trades comment `PH_BNC` / `PH_HD` / `PH_PSR`; magic `InpTradeMagic`
- FVG: SL helper only (`Phase_FVG.mqh` — Future2EA detect + 2nd/3rd dyn SL)
- FVG concept (docs): Brown=open; Grey/iFVG=through≥1; gone=through≥2; through = full-body / multi-candle opp close / half-open→out
- F2E draw ref: burlywood open + dim-gray filled; width clamp 30–1000; objs `PH_FvgB_/FvgR_`; soft brown reject unlock+1 (not CloseAll)
