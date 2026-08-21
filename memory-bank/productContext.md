## Why
Traders need a clear visual of whether price is in a bullish RSI bounce band (35–80) or bearish band (20–65), including historical context, plus live bounce/S&R entries with FVG stops.

## How it should feel
- Professional dark green/red tints — obvious but not neon
- RSI pane levels always visible
- History strips show when regime flipped
- Body boxes highlight open–close structure after pullback candles

## UX
Attach EA to chart → Phase_RSI appears → background + strips + boxes update on new bars. Live bounce / price-S&R / HD trades when enabled; SL from 2nd FVG (else min pips); exits via Div / regime / SL.

**0-1-2:** 0 = sirf regular Div (zone 35-40/60-65 mein nahi). Path Div side se: <35 → 60-65 then 35-40; >65 → 35-40 then 60-65. Far-side cross (65 / 35) bina sharp bounce = invalidate until next Div.
