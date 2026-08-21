## Current focus
v1.58: ignite pe Div→012 **replay + stamp paint**; FarKill mere Above65 pe DIE nahi (1 miss fix); HiReject loose 60-65.

## Bug (chart)
1 @ 60-65 → dump <35 → bounce 35-40 pe **2** lag jata **pehle**; Div confirm baad mein **0 DIV** pivot pe. Fix: step1 pe 35 cross = dead; Mark0 agar evt2Time > divT to 2 stamp hatao. Logs: `Phase Loop: 0/1/2/DIE`.

## 0-1-2 loop
- **0** = sirf regular Div (pivot pe stamp). 35-40 / 60-65 ke andar 0 nahi. 1 ke baad naya Div = naya 0, **2 nahi**
- **Div <35:** wait **59-65** reject/bounce (65 sharp-down bhi) → **1**; phir **35-41** bounce (35 sharp-up bhi) → **2** BUY. 65 cross bina sharp reject → **dead** (no 1/2 until next Div)
- **Div >65:** wait **35-41** bounce (close **>35**) → **1**; phir **59-65** → **2**. Close **≤35** = **dead** (1/2 nahi, isi zone mein 2 nahi)
- 1 aur 2 hamesha opposite zones; ek hi 35-40 ya 60-65 band mein dono nahi
- Latch at 2 until next regular Div (classic 35/65 block)
- **2 ke baad 50-zone = 44–54 (yellow lines on Phase_RSI):**
  - wait bounce/reject inside 44–54 → regime flip
  - through **>54** (BUY latch) / **<44** (SELL latch) → no 50-flip
  - BUY latch: 44–54 reject DOWN → SELL; SELL latch: 44–54 bounce UP → BUY
- Latch: classic 35/65 block until next Div
- Step **1** invalid (extreme break): 1 stamp hataye, 0 rahe, path wait. Far-cross dead = 1 bhi hataye
- Div>65 / SELL path: **1 at 35-40** ke baad **35 cross ya stay** → **1 cancel + loop dead** (2 nahi)
