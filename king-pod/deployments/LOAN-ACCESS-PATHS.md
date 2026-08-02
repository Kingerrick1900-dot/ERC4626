# LOAN ACCESS WITHOUT MORPHO BLUE COLLATERAL — FINDINGS

**Honest line:** Morpho Blue **lasting** `borrow` has **no loophole** — core reverts `INSUFFICIENT_COLLATERAL` if coll/HF fail.  
**Great news:** Kingdom already has **two Morpho-adjacent paths** that do **not** post Elepan on Blue.

---

## Path A — Morpho flash (official, no coll)

Morpho docs: flash borrow **without prior collateral**; must repay **same tx** or full revert.  
Kingdom already uses this (`CrownElepanFatFlashSeed`, `$9M` seeder).  
**Not** standing debt — atomic tool only.

## Path B — ZK credit rail (LIVE) — the standing “around”

| Piece | Status |
|--|--|
| `CrownZkElepanGate` | `isProven(hot)=**true**`, threshold **$700k** |
| `CrownZkElepanCredit` `0xc415…d936` | gate wired, Landing receiver, LLTV **70%** |
| Draw rule | proven subject borrows ≤ `threshold × 70%` → Landing (**no** `Morpho.supplyCollateral`) |
| Max vs current attestation | **$490k** room |
| Blocker today | credit pool USDC bal = **0** → `maxBorrow(hot)=0` until lenders (or King) `supply` USDC |

Scale: re-prove at higher threshold (bag supports ≫$700k) + fill pool → larger ZK draws still **without Blue coll**.

## Path C — $14M Morpho vault seed

Still needs Elepan on Blue for the **borrow leg** — but King **already holds** ~99.9M Elepan. Not missing coll inventory; it’s posting your own bag.

---

## Verdict

| Want | Need Morpho Blue coll? |
|--|--|
| Standing Morpho Blue loan | **Yes** |
| Same-tx flash machine | **No** (repay same tx) |
| ZK credit → Landing | **No** (needs pool USDC + proof) |

**No fire in this note.** Fill ZK pool / raise proof threshold / or GO $14M with own Elepan — King chooses.
