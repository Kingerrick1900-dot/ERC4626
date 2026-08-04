# FOUR LIVE AVENUES TO USDC

**King correction:** The escrow machine is theater. Real cash rides the paths already built.  
**Target:** spendable USDC on Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`.  
**Law:** Elepan free · loan ≠ dump RSS · no yRSS payroll loop · flash ≠ lasting cash.

Escrow `fill()` is **not** an avenue. It waits on an empty bowl. These four do not.

---

## Avenue 1 — Bound Completer / Permit2 (LIVE machine)

| Piece | Address | State |
|--|--|--|
| Gate | `0xab2856626BBd8E6fba9dB93783029eB973E8427F` | **isProven(hot)=true @ $700k** |
| Credit | `0x20B1513a137b9CB166E2cC15c405e842278E7D1A` | pool $0 · maxAsk path open |
| Permit2 Completer | `0xA247c1d0Ad4E7690764E456E5d8d315bA2912468` | **operator=true** |
| Classic Completer | `0x3827dA0c33891ee058847BB896D6287C5814F7C6` | **operator=true** |
| AutoDraw | `0x364bef6c5a3dc2c02d7ecf1e12a2d1f08b0513ba` | **operator=true** |
| maxAsk | — | **$490,000** (70% × $700k) |

**Cash path:** matcher/hot USDC → `complete(amount)` → `credit.supply` → `operatorBorrowTo(Landing)` → Landing += amount.

```bash
python3 king-pod/script/FireFundBoundCredit.py --watch --fire --amount 490000
python3 king-pod/script/SucceedWatch.py --ask 490000 --poll --auto-complete
```

Packet: `MATCHER-PERMIT2-PACKET.md`

---

## Avenue 2 — Tenor Fixed RFQ (LIVE inquiries)

| Inquiry | ID |
|--|--|
| Armitage | `7e35d157-3dfe-40bc-81e5-e0841037976d` |
| Broadcast | `caaa6250-04c3-4b9a-98e1-64531f67be97` |

**Cash path:** desk prices offer onchain → accept → USDC to hot → route Landing. True RSS collateral. Elepan never in collateral.

```bash
TENOR_BEARER=... python3 king-pod/script/WatchTenorRfq.py --poll
python3 king-pod/script/SucceedWatch.py --ask 500000 --poll
```

**Block now:** bearer returns `Unauthorized` on offer queries — refresh Tenor auth, then hunt continues. Inquiries remain the rail; auth is the key, not a new escrow.

---

## Avenue 3 — eUSD inventory unlock (LIVE inventory)

| Wallet | eUSD |
|--|--|
| Landing | ~**800k** |
| Hot | ~**100k** |
| Maker PSM `0xfFEd…4977` | USDC reserve ~**$1.46** (dust) |

**Cash path:** capitalize PSM / deep eUSD-USDC pool → `redeem` → Completer → Landing. Inventory is already held — block is **depth**, not “find eUSD.”

Do not value eUSD in a getter as USDC payroll. Convert with depth, or King-named PSM seed tranche.

---

## Avenue 4 — Morpho idle + Foreign PA + Bundler3 (LIVE bots)

| Piece | State |
|--|--|
| RSS market idle | ~**$1** (not green) |
| Foreign PA maxIn (Gauntlet/Steakhouse) | **0** |
| Own yRSS PA caps | maxIn/maxOut **$700k** · maxWithdraw ~$1 |
| Free RSS (hot) | ~**8.8M** (after seed escrow; still collateral) |
| Bundler3 | `0x6BFd8137e702540E7A42B74178A4a49Ba43920C4` **PRIMARY EXECUTOR** |
| SpoilFire | `0xcFF60f3B071c09C17853bA715ceDc0Fc2e6645Fa` |

**Cash path:** idle ≥ ask **or** foreign `maxIn>0` → Bundler3 atomic pack / SpoilFire → Landing. Borrow against posted RSS. No self-supply payroll loop.

```bash
python3 king-pod/script/ScanAllRails.py --auto-fire --ask 500000
python3 king-pod/script/ScanAllRails.py --poll --interval 60 --auto-fire
python3 king-pod/script/watch_maxin_fire.py
```

---

## What is theater

| Fake primary | Why |
|--|--|
| Empty RSS escrow waiting for a stranger | Bowl with no cook — not a cash path |
| Flash / balanceOf reflection | Same-block repay zeros Landing |
| yRSS TVL as payroll | War chest, maxWithdraw≈0 |

Escrow contract may stay deployed as an optional side door. It is **not** Avenue 1–4.

---

## Chief run order (first cash wins)

1. **SucceedWatch** — Avenue 1 + 2 in parallel  
2. **ScanAllRails --auto-fire** — Avenue 4  
3. **eUSD depth / PSM capitalize** — Avenue 3 (King-named size)  
4. Escrow fill — ignore unless someone hits it unprompted  

## Scoreboard

```
Landing_USDC ↑
Avenue_that_paid ∈ {1,2,3,4}
Elepan_untouched = true
escrow_primary = false
```
