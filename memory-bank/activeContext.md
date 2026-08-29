## Current focus
v1.70: pehla 2 pe 50 flip; <35 seedha-up / >65 seedha-down → 2 replace once (50 OFF). Circled dip Div nahi — 2nd RSI 35-40 dead zone.

## Bug (chart)
1 @ 60-65 → dump <35 → bounce 35-40 pe **2** lag jata **pehle**; Div confirm baad mein **0 DIV** pivot pe. Fix: step1 pe 35 cross = dead; Mark0 agar evt2Time > divT to 2 stamp hatao. Logs: `Phase Loop: 0/1/2/DIE`.

## 0-1-2 loop
- **0** = sirf regular Div (pivot pe stamp). 35-40 / 60-65 ke andar 0 nahi. 1 ke baad naya Div = naya 0, **2 nahi**
- **0 DIV extreme break (step 0/1):** Div peak se **upar** (path -1) ya Div trough se **neeche** (path +1) → **DIE** until next Div. Step 2 latch pe nahi
- **Div <35:** wait **59-65** reject/bounce (65 sharp-down bhi) → **1**; phir **35-41** bounce (35 sharp-up bhi) → **2** BUY. 65 cross bina sharp reject → **dead** (no 1/2 until next Div)
- **Div >65:** wait **35-41** bounce (close **>35**) → **1**; phir **59-65** → **2**. Close **≤35** = **dead** (1/2 nahi, isi zone mein 2 nahi)
- 1 aur 2 hamesha opposite zones; ek hi 35-40 ya 60-65 band mein dono nahi
- Latch at 2 until next regular Div (classic 35/65 block)
- **2 ke baad 50-zone = 48–53 (yellow lines on Phase_RSI):**
  - wait bounce/reject inside 48–53 → regime flip
  - through **>53** (BUY latch) / **<48** (SELL latch) → no 50-flip
  - BUY latch: 48–53 reject DOWN → SELL; SELL latch: 48–53 bounce UP → BUY
- Latch: classic 35/65 block until next Div
- Step **1** invalid (extreme break): 1 stamp hataye, 0 rahe, path wait. Far-cross dead = 1 bhi hataye
- Div>65 / SELL path: **1 at 35-40** ke baad **35 cross ya stay** → **1 cancel + loop dead** (2 nahi)
