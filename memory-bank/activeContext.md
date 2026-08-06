## Current focus
v1.41: live bounce trades + Div/regime exits (visual regime engine unchanged).

## Decisions
- Past closed-bar regime colours never recalculated
- Stick until INV/S&R leave (existing Buy/Sell Process)
- `g_walk` + `g_srList` persist after ignite
- S&R line sirf apni regime ke andar
- HD toggle = left button; F2E dash nahi
- Trade: arm on RSI zone touch, fire on opposite closed RSI move; stack per bounce
- Regime flip → CloseAll; regular red Div → close buys; green → close sells
- Ignite/history pe trades nahi

## Next
- Chart pe bounce entries + Div/regime CloseAll verify
- Optional: live BOS truncate on break (helpers already in Phase_BOS)
