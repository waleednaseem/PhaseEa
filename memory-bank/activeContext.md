## Current focus
SELL leave = BUY mirror: stay above resist S&R (RSI INV) → flip BUY; Div ≠ regime leave.

## Decisions
- Past closed-bar regime colours never recalculated
- Stick until INV/S&R leave (Buy/Sell Process)
- BUY leave: RSI stay below support INV (else <35) → SELL
- SELL leave: RSI stay above resist INV (else >65) → BUY (`PhSell_Process` mirror)
- S&R on RSI window only; price Div/BOS does not flip regime
- `g_walk` + `g_srList` persist after ignite
- Regime = parent: opposite HD/Div never unlock or open
- Stack loss: ≥4 opens — n=4 last 1 / n>4 last 2 all loss → CloseAll unlocked
- Against Div+BOS → CloseAll + lock; unlock support HD/Div+BOS/FVG/realign

## Next
- Chart QA: SELL stay-above resist S&R flips to BUY
