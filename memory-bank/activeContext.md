## Current focus
v1.45: perf (FVG cache / PriceSR / dash) + SL floor 800 pips + FVG defaults.

## Decisions
- Past closed-bar regime colours never recalculated
- Stick until INV/S&R leave (existing Buy/Sell Process)
- `g_walk` + `g_srList` persist after ignite
- S&R line sirf apni regime ke andar
- HD toggle = left button; F2E dash nahi
- Trade: arm on RSI zone touch, fire on opposite closed RSI move; stack per bounce
- BUY also: 60–65 pullback bounce-up; SELL also: 35–40 bounce-down
- Extra RSI S&R: last 100 RSI swings (str=2); support <35 / resist >65; scan≠draw (window missing pe bhi levels); arm→fire bounce/reject
- SL = 2nd/3rd FVG only if ≥800 pips (PhTrade_PipSize); else min 800; no fixed TP
- Regime flip → CloseAll + unlock; regular red Div → close buys; green → close sells
- Unlock = supporting HD **or** supporting regular Div **or** brown FVG soft reject
- FVG reject: BUY upper from-below reject-down / SELL lower from-above reject-up → unlock + 1 entry (`PH_FVG`); skip grey/full-through; no CloseAll
- FVG/iFVG **drawn** on main chart (`PH_Fvg*`); trade logic independent of ShowFvg
- Ignite/history pe trades nahi
- **Perf:** FVG cache (lookback 800 / maxShow 12 / width 1000 clamp 30–1000); incremental fill; PriceSR redraw-on-change; Loss hist 5s throttle

## Next
- Chart QA: brown reject unlock+1 trade; bounce/HD/Div still OK; SL never <800 pips
