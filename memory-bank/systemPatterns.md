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
**0** = regular Div only (restart/unlock; stamp 0). **1** same-side bounce ± PriceSR sharp. **2** opposite bounce ± PriceSR sharp → flip + latch (stamp).
After 2, ignore opposite until next regular Div. No HUD. 1 invalid = stamp 1 remove, no 0 stamp.

SELL: 1=60-65 / near-65 SR, 2=35-40 / near-35 SR→BUY. BUY: mirror.

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
