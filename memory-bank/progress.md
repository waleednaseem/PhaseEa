# Phase — Progress

## Done
- Daily auto balance; ±10% of that day → stop. Book 5% → 2% after +15% vs run-start
- Regime freeze (ignite-once) + S&R + Phase dash/LOSS
- v1.39: Div + HD + Div-related BOS/INV (Future2EA port)
- v1.41: bounce trades, regime CloseAll, Div side CloseAll, SL lock + HD unlock/entry
- v1.42: FVG 2nd-SL helper, extra RSI bounce zones, price S&R 100-bar, Div+HD unlock
- v1.46: against Div+BOS CloseAll+lock; unlock support HD/Div+BOS/realign≤5 (buy+sell)
- v1.47: stack-loss CloseAll on last 1/2 trades, stay unlocked
- v1.48: opposite-zone bounce-switch (35-40 up → BUY, 60-65 down → SELL) without 35/65 cross
- v1.49: ping-pong latch — zone CROSS (35 down / 65 up) kills bounce-switch; regime stays
- v1.50: one opposite bounce switch then latch (SELL→35-40 bounce→BUY stays; mirror for BUY)
- v1.51: 60-65 reject re-arms ping-pong so 35-40 bounce can start BUY
- v1.52: **0-1-2 loop khatam** — 0 SELL start → 1 60-65 reject → 2 35-40 bounce BUY latch (60-65 ignore)
- v1.53: 0 = 35-65 bahar (mid-regime bhi); BUY 0-1-2 = 35-40 then 60-65 → SELL
- v1.55: 0-1-2 **path = Div side** (not regime); 0 not in 35-40/60-65; 1+Div ≠ 2; same-band 1+2 band; 65/35 through without sharp → dead until next Div
- After 2: **50 bounce/reject** → regime switch again (BUY reject-down / SELL bounce-up)

## Left
- Live chart QA: Div<35 → 60-65=1 then 35-40=2; Div>65 mirror; far-cross kills loop

## Known issues
- Fixed v1.29: history rewrite / unpredictable regime colour flips
