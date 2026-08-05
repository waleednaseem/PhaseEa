# Phase — System Patterns

## Layout
```
Experts/Phase/
  Phase.mq5
  Include/
    Phase_Types.mqh
    Phase_SR.mqh
    Phase_BuyRegime.mqh
    Phase_SellRegime.mqh
    Phase_Regime.mqh
    Phase_Draw.mqh
    Phase_Dash.mqh          # M1..H1 regime panel (top-right)
```

## Flow
OnInit → IgniteHistory (one PhBuildRegimes) → freeze g_regimes + g_walk
OnTick new bar → PhRegimeAdvance (shift frozen + step shift=1) → paint

## Conventions
- Config: `g_cfg` loaded once
- No full 500-bar re-walk after ignite
- INV never at/near 35/65; S&R stops on regime END
- Objects: prefix `PH_`
