# FREEZE — refine “2-tx Landing payroll, no OTC / no cbBTC”

**Mode:** FREEZE · plan only · **do not broadcast**  
**Rail:** `CrownKingRail` `0xaE87f8124999b20F870Ef92491133b897e1b14c8`  
**Verdict:** Proposed TX1/TX2/TX3/TX4 as written is **unsafe / non-executable**. Below is the corrected physics.

---

## Live facts (do not argue with the chain)

| Check | Live |
|--|--|
| yRSS claim `convertToAssets(HOT)` | ~**$1,010,764** |
| `yRSS.maxWithdraw(HOT)` | ~**$1.51** (= park idle) |
| HOT USDC | **0** |
| HOT cbBTC | **1028 wei** dust |
| Landing USDC | ~**$0.20** |
| Landing ETH | ~**0.000145** (≪ 0.02) |
| `yrss.allowance(HOT, rail)` | **0** |
| Rail `gasPark` / `borrow` | **revert `NoBorrow`** |
| Rail P3 | `p3PayrollWithCbbtc(usdc, cbbtc)` — **`cbbtcColl == 0` reverts `BadAmt`** |

---

## Kill sheet — errors in the draft plan

| Draft claim | Reality |
|--|--|
| **TX1 from Landing key** `yrss.approve(rail)` | **Wrong signer.** yRSS shares sit on **HOT**. Only HOT can approve. Landing key cannot authorize HOT’s shares. |
| **“P3 temp payroll, no cbBTC needed”** | **False on this rail.** Live P3 pulls cbBTC, posts coll, **borrows cbBTC/USDC book** to repay flash. `cbbtcColl = 0` → revert. |
| **Flash → `engineerIdle(1.5M)` → peel $1.01M → repay with 1.01M+0.49M** | **Fails conservation.** Supplying flash into park then peeling $1.01M to Landing **removes** that USDC from the repay set. Remaining supply ≈ $0.49M ≠ $1.5M flash. The “$0.49M from tx” does not close the hole unless someone **brings $1.01M** (or borrows it on another book). |
| **“gasPark dead” but L6 still same-book** | Correct that gasPark is dead. Incorrect that a no-coll flash peel still works. Old doc line “repay = HOT park supply withdraw” **collides** with peel: repay-open idle and vault withdraw **consume the same idle**. That is why P3 was rebuilt onto **cbBTC book ≠ park**. |
| **TX3: $100k → ~0.9 cbBTC** | At ~$79k/BTC, $100k ≈ **1.26 BTC**, not 0.9. Minor. Larger issue: **no $100k until payroll exists**. |
| **Loop TX3→TX4 to 23 cbBTC** | Directionally right **after** first USDC exists — but **bootstrapping the first USDC without coll/OTC/inbound is the missing step**. Circular. |

**Seat line:** No OTC + no cbBTC + no inbound USDC ⇒ **no $1.01M Circle payroll** and **no lasting idle**. Code cannot invent Morpho USDC.

---

## What P3 actually does (armed rail)

```
onlyKing (HOT):
  cbbtc.transferFrom(HOT → rail, coll)     // REQUIRED
  flash USDC = payroll amt (≤ claim ~$1.01M)
  → repay HOT park debt                     // opens idle
  → yrss.withdraw(amt, Landing, HOT)        // needs allowance HOT→rail
  → supplyCollateral cbBTC + borrow USDC    // repay flash from cbBTC book
```

| Deliverable | After success |
|--|--|
| Landing | +~**$1.01M** Circle USDC |
| Park lasting idle | ~**$0** (expected — payroll not idle) |
| Rail / Morpho | cbBTC coll posted · USDC debt on cbBTC/USDC book |

**Coll floor (haircut ~95% LLTV @ ~$79k):** for **$1.01M** flash/borrow ≈ **~15.6 cbBTC** (not zero).  
($1.5M lasting P4 still ≈ **~23.2 cbBTC** on puller `0xE55f…6F3B`.)

---

## Corrected freeze plan (no OTC named — honest gates)

### Gate A — Signer map (fix first)

| Action | Signer |
|--|--|
| `yrss.approve(rail, max)` | **HOT** (not Landing) |
| `cbbtc.approve(rail, coll)` | **HOT** |
| `rail.p3PayrollWithCbbtc(0, coll)` or `(1010764308056, coll)` | **HOT** |
| `rail.p1LandingWithdrawEusd(amt)` | **Landing** only |
| Gas on Landing | Landing ETH — top up if using Landing for P1 |

### Gate B — First USDC without OTC (pick one; freeze until named)

There is **no** 2-tx HOT/Landing path that prints $1.01M USDC from yRSS while park idle is $1.51 and gasPark is blocked.

| Option | How first USDC/cbBTC appears | Then |
|--|--|--|
| **B1 cbBTC treasury** | King/treasury sends ≥~**15.6 cbBTC** to HOT (not called OTC if internal) | HOT approve yRSS+cbBTC → P3 → Landing +$1.01M |
| **B2 inbound USDC** | Foreign/deposit/payroll rail lands USDC on HOT or Landing | Direct park supply (lasting idle) **or** buy cbBTC → P3/P4 |
| **B3 peel dust only** | No flash | `maxWithdraw` ~**$1.51** to Landing — real but tiny |
| **B4 eUSD only** | Already done (P2) | Landing holds ~**$2M eUSD** — **not** Circle USDC |

**Rejected while freeze:** any calldata pack for “P3 with `cbbtcColl=0`” or “engineerIdle then peel then hope.”

### Gate C — After Landing has ≥$1.01M USDC (compound — your TX3/TX4, fixed)

No-OTC **compound** is valid **only after Gate B**:

1. Landing/HOT swaps a **slice** USDC→cbBTC (Uni/Aero Base, fee 500 pool deep).  
2. Send cbBTC → HOT.  
3. HOT fires **P4** / `CrownCbbtcIdlePuller.pullIdle` for **partial** lasting park idle (coll-limited).  
4. Repeat: leave a growing lasting buffer; do **not** recycle full payroll into gasPark.  
5. Stop compound when lasting idle ≥ King buffer (**$1.5M** ⇒ ~**23.2 cbBTC** total posted over path).

**Efficiency note:** USDC→cbBTC→P4 yields ~**haircut×LLTV** lasting idle per USDC spent. **Direct `engineerIdle` supply** yields **100%** lasting idle per USDC. Prefer direct supply for lasting idle; use cbBTC L2 when the equity is **already BTC-denominated**.

### Gate D — Key hygiene

HOT key was exposed in chat → **rotate before any large approve/P3**. Freeze holds until rotation confirmed.

---

## Replacement “tx list” (freeze — not calldata)

| # | Signer | Action | Status |
|--|--|--|--|
| 0 | Ops | Rotate HOT; fund coll **or** name B2 inbound | **BLOCKING** |
| 1 | HOT | `yrss.approve(rail, max)` | Ready after 0 |
| 2 | HOT | `cbbtc.approve(rail, coll)` · coll ≥ quote for amt | Ready after 0 |
| 3 | HOT | `rail.p3PayrollWithCbbtc(amt, coll)` | Payroll; idle not lasting |
| 4 | Landing/HOT | Optional compound USDC→cbBTC→P4/puller | After 3 |
| — | Landing | `p1LandingWithdrawEusd` | Parallel eUSD track; ≠ USDC payroll |

---

## Calldata request

**No.** Freeze mode + broken draft = **do not encode Base mainnet hex for TX1/TX2 as proposed.**  
When Gate B is named and funded, encode **HOT** approve + `p3PayrollWithCbbtc` with **non-zero coll** only.

---

## Seat line

**No OTC** does not mean **no equity**. First pull now without cbBTC/USDC in = **revert or self-lock**.  
Armed machines wait: KingRail P3/P4 · CbbtcIdlePuller `0xE55f…6F3B`.  
Name **B1** or **B2**, then lift freeze for that tx set only.
