# Phase — System Patterns

## Layout
```
Experts/Phase/
  Phase.mq5
  Include/
    Phase_Types.mqh
    Phase_SR.mqh            # RSI swing Support/Resist
    Phase_BuyRegime.mqh
    Phase_SellRegime.mqh
    Phase_Regime.mqh
    Phase_Draw.mqh
```

## Flow
OnInit → LoadConfig → iRSI + Phase_RSI
OnTick → PhBuildRegimes (S&R swings) → paint strips/boxes/signals + RSI S&R lines

## Conventions
- Config: `g_cfg` loaded once (no re-declare zones every bar)
- Buffers: `g_rsi[]`, `g_regimes[]` reused
- Buy/Sell logic isolated; overlap sticky in Process functions
- Objects: prefix `PH_`
