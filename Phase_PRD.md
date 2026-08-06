# Phase RSI Regime EA — PRD v1.42

## Goal
Visual + live trade EA: Constance Brown RSI **range-shift** regimes, Div/HD, bounce entries, **FVG-based dynamic SL**.

## Source
Brown, *Technical Analysis for the Trading Professional* Ch.1; FVG/SL from Future2EA (`F2E_FVG.mqh`).

## RSI
- Period: **14**
- Companion: `Phase_RSI` — levels 20/35/40/50/60/65/80

## Regime (sticky) — default Neutral
**Bull (green):** RSI breaks **above 65**, then holds **≥40**  
**Bear (red):** RSI breaks **below 40**, then stays **≤65**  
**End:** leave bull close &lt;40 → grey; leave bear close &gt;65 → grey  
Freeze: OnInit one ignite walk; live = `PhRegimeAdvance` only.

## FVG / iFVG (complete concept from Future2EA)

Source of truth: `Future2EA/Include/F2E_FVG.mqh`, `F2E_Types.mqh` (`SF2E_Fvg`), `Future2EA.mq5` inputs, PRD §8.  
**Phase today:** `Include/Phase_FVG.mqh` — detect + dyn SL + chart brown/grey draw (v1.43). Brown-reject CloseAll, bias-FVG, IFVG+FVG pair flip — **not ported**.

### Naming
| Name | Meaning |
| ---- | ------- |
| **Brown = FVG** | Open / unfilled zone (`filled=false`, through-cross = 0) |
| **Grey = iFVG** | Zone that has been **through-crossed** once (`filled=true`, through ≥ 1) |
| **Gone** | Through ≥ 2 → zone removed from collect/draw |

Struct fields (`SF2E_Fvg` / Phase `SPhFvg`): `valid`, `isBull`, `filled`, `gapTop`, `gapBottom`, `detectTime` (C3 bar), `c3Shift` (+ F2E `widthBars` unused in Phase).

### Detection (3-candle wick gap)
Bars at detect shift: **C1** = `shift+2`, **C2** = `shift+1`, **C3** = `shift`. Gap completes on C3 (`detectTime` = C3 time). Min gap = `InpFvgMinGapPoints * _Point` (default **30** points).

**Bull FVG** — C2 bull impulse (`c2 > o2`):
1. Standard: `h1 < l3` → zone top = `l3`, bottom = `h1`
2. Pierce variant (C3 wick pierces into C2): `h1 < l2` → zone top = `l2`, bottom = `h1`
3. Else no bull FVG. Require `gapTop - gapBottom ≥ minGap`.

**Bear FVG** — C2 bear impulse (`c2 < o2`):
1. Standard: `l1 > h3` → zone top = `l1`, bottom = `h3`
2. Pierce: `l1 > h2` → zone top = `l1`, bottom = `h2`
3. Else no bear FVG. Same min-gap filter.

Doji C2 (`c2 == o2`) → no FVG.

### Brown vs Grey — through-cross rules
Scan candles after C3 (oldest→newest). Outer side: price `< gapBottom` → −1, `> gapTop` → +1, else 0 (inside/edge).

A **through** increments when any of:
1. **Full-body opposite:** open on one outer side, close on the other (same candle)
2. **Multi-candle opposite closes:** previously closed/remembered on one outer side, later candle closes on the opposite outer
3. **Half/inside open → out:** open inside/edge (`openOuter==0`), close outside, and that outer ≠ last remembered outer

State machine:
- Through **0** → **brown** (open FVG)
- Through **≥ 1** → **grey / iFVG** (`filled=true`)
- Through **≥ 2** → **zone gone** (skip collect/draw)
- Close **inside** only → stays brown (does not count as through)

Legacy soft/full edge crosses (`F2E_FvgFullCrossCounts`) exist for trade re-arm / “already crossed” checks; visual grey uses **through** only.

### Styling (Future2EA defaults — for future Phase draw)
| Input | Default | Role |
| ----- | ------- | ---- |
| `InpShowFvg` | `true` | Draw on/off |
| `InpFvgLookbackBars` | `800` | Scan window (cached; incremental new-bar) |
| `InpFvgMinGapPoints` | `30` | Min wick gap (points) |
| `InpFvgMaxShow` | `12` | Max zones on chart (newest first) |
| `InpFvgMinWidthBars` | `30` | Box width clamp min |
| `InpFvgMaxWidthBars` | `1000` | Box width clamp max |
| `InpFvgWidthBars` | `1000` | Box extend (clamped 30–1000) |
| `InpColorFvgFill` | `C'222,184,135'` | Brown/open fill (burlywood) |
| `InpColorFvgBorder` | `C'101,67,33'` | Brown/open border |
| `InpColorFvgFillFilled` | `C'105,105,105'` | Grey/iFVG fill (dim gray) |
| `InpColorFvgBorderFilled` | `C'64,64,64'` | Grey/iFVG border |

**Draw:** filled rectangle from `detectTime` → `detectTime + widthBars * PeriodSeconds`; fill/border swap by `filled`.  
**Object naming (F2E):** prefix `F2E_`; bull `F2E_FvgB_<detectTime>`, bear `F2E_FvgR_<detectTime>`; delete tag `F2E_Fvg*`. Phase would use `PH_` if/when ported.  
F2E also gates chart FVG to M1 + live + `!HideObjects` (history scan does not paint).

Related F2E-only inputs (trade/pair, not Phase SL): `InpIfvgFvgMaxPips=200`, `InpFvgHitFlipMin=2`, `InpBosFvgEarlyBars=4`.

### Trade-related FVG behavior in Future2EA (reference)
**Soft brown reject → CloseAll** (grey / already-crossed / full-body through → **no** CloseAll):
- **BUY seq:** brown FVG **above** price (touch from below) → 1× soft reject-down (close back below zone) → CloseAll + limit reset
- **SELL seq:** brown FVG **below** (touch from above) → 1× soft reject-up (close back above zone) → CloseAll + limit reset
- Wrong side (sell+upper / buy+lower) → unlocked CloseAll **no**; breakout → clear pending only
- Soft reject CloseAll → **seq LOCK** + **2-candle** trade cooldown; unlock = HD / BOS / RSI-bounce — **FVG does not unlock**
- **No dual-iFVG CloseAll** (last-2 grey does not flatten)
- Bias FVG (M1+M5): upper FVG→SELL / lower→BUY after touch→reject→2 confirm candles (1/zone)
- IFVG+FVG pair after BOS (within max pips) was for multi-hit flip — **disabled** in F2E; brown soft reject path remains

**Dyn SL** (ported to Phase):
1. Collect active FVGs (through &lt; 2) in lookback
2. Side window from entry: sell = zones above; buy = zones below; within `InpStopLossPoints` (F2E default 1500 pts)
3. Sort nearest→far; SL level = sell `gapTop` / buy `gapBottom`
4. Prefer **2nd** FVG if distance ≥ **max(800, InpSL_Pips)** pips (`PhTrade_PipSize`); else **3rd** if ≥ same floor; else **min-pips fallback** (never tighter than 800)
5. `InpRequireFvgSl` (F2E, default false) — if true and no FVG SL → skip entry; Phase always allows fallback

### Phase current state
| Feature | Phase |
| ------- | ----- |
| Detect + through/filled for SL scan | Yes (`Phase_FVG.mqh`) |
| Dyn SL 2nd/3rd/fallback | Yes |
| Chart brown/grey boxes | Yes (`PH_Fvg*`, `InpShowFvg`) |
| Brown-reject CloseAll / cooldown / lock-from-FVG | **No** |
| Bias FVG / IFVG+FVG pair | **No** |

## Trade (v1.42)
### Entries (live new-bar only)
- **BUY regime:** bounce from 35–40 or 50; **also** pullback into 60–65 then bounce up while ≥60 → buy
- **SELL regime:** bounce from 60–65 or 50; **also** bounce down from 35–40 → sell
- **Extra RSI S&R:** last 100 bars RSI swing H/L (str=2); support **<35** / resist **>65** only (mid 35–65 skip); **dotted** on RSI pane; support bounce → buy (bull); resist reject → sell (bear)
- Support **HD:** bull+hidden bull → buy; bear+hidden bear → sell (`PH_HD`)
- Lot 0.01; **no fixed TP**; SL = 2nd FVG (else min 800 pips)

### Exits / lock
- Regime change → CloseAll (+ unlock fresh seq)
- Red regular Div → close buys; green → close sells
- SL hit → CloseAll + **seq LOCK**
- **Unlock:** supporting HD **or** supporting regular Div (buy: green / HD bull; sell: red / HD bear)

## Divergence / BOS / HD
Regular + HD from Future2EA port; live flags on `SPhDivState`.

## Drawing
Prefix `PH_`; modules Buy/Sell/Regime/SR/PriceSR/FVG/Draw/Dash/Div*/Trade.

## Non-goals
Docker, sibling EA edits, FVG chart paint / brown-reject CloseAll (for now).
