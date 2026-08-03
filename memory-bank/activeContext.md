## Current focus
v1.28: regime END pe S&R line stop (INV dead); lookback ghost fix; no-INV exit fallback.

## Decisions
- S&R line sirf apni regime ke andar (start=enter, end=regime close)
- Lookback level pivot se, draw pehli regime mein nahi
- Bina INV: leave SELL on stay >65 / leave BUY on stay <35
- Resist = highest >65+gap | Support = lowest <35-gap
