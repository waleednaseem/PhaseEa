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
- INV never at/near 35/65 (`invGap`); BUY INV = StartBuy lookback + CaptureDuring
- Regime colour lock after enter (`barsInRegime` > hold+confirm)
- Objects: prefix `PH_`
