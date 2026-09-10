# FREEZE — Elephant Brave C / “become the lender” wall-break

**Mode:** FREEZE · staff audit of the Majesty brief  
**Verdict:** Status read is mostly right. **C-as-written does not break the wall.** `CrownEusdBorrowUsdc` is still worth writing — as Phase **after** real USDC seed, not as a mint from eUSD ocean.

---

## Status translation — corrected

| Line | Keep? | Fix |
|--|--|--|
| Unlatch $1.51 · deed ~$1.01M matched | **Yes** | Wall on peel |
| FakeIdle / ocean / P2 eUSD = optics for Circle | **Yes** | Real for **eUSD** rails |
| Puller/Rail armed · pulled 0 | **Yes** | |
| Curator favor · queue · PA $2M · Landing allocator | **Yes** | Fired live |
| “ZK prove door unproven, so no HOT” | **No** | HOT USDC=0 is **wallet empty**, not ZK. ZK gate is OTC attest; unrelated to HOT balance. |
| Boss eUSD/USDC ~$0.80 waits on lenders | **Yes** | **The wall** |
| “idle never becomes park because borrow never happens” | **Soft no** | Queue routes **new deposits** into boss book. Idle≠park is not caused by missing borrow; park latch is separate. Borrow-vs-eUSD needs **USDC lenders on boss book**. |

---

## Why “become the lender” fails as written

Claimed C loop:

```
$1.9M eUSD → Aero → cbBTC → Morpho borrow USDC → lend boss book → CrownEusdBorrowUsdc
```

| Step | Live physics |
|--|--|
| eUSD → Aero | Ocean is **eUSD/gUSD** mint–mint — **no Circle out** |
| eUSD → USDC DEX | Uni still **dust** (~$0 USDC in pool) |
| eUSD → cbBTC | No funded path at size |
| “~24.7 BTC after C-fire” | **Assumes** the swap already worked — circular |
| Lend boss book | Requires **USDC in hand first** |
| Then borrow vs eUSD | Recycles that same USDC (useful) — does **not** create the first dollar |

**Self-lend pattern that *is* legal (when you already have USDC F):**

```
supply F USDC to boss (eUSD/USDC)
→ post eUSD coll
→ borrow ≤ 0.86 × coll
→ move borrowed USDC to park (lasting idle) or Landing
```

Net: eUSD locks as coll; **F must exist before the loop**. Becoming your own lender **moves** Circle you already control; it does not print it from the ocean.

**“PA inbound from C”** misnames Public Allocator. Supplying your own USDC to boss is **direct supply**, not PA. PA still needs **foreign vault** shared liquidity into park/boss (hallway still empty for park).

---

## What actually breaks the wall (ordered)

| # | Breaker | Creates first USDC? |
|--|--|--|
| 1 | **External USDC** into yRSS/boss/HOT (depositors, desk/ZK wire, treasury) | Yes |
| 2 | **cbBTC/WETH** → Puller/P3/P4 (foreign book idle) | Yes (borrow) |
| 3 | **Foreign PA** into park/boss when shared liquidity > 0 | Yes (route) |
| 4 | **Self-lend recycle** (CrownEusdBorrowUsdc) after 1–3 | No — shapes idle/peel |
| 5 | eUSD → Aero → cbBTC “C” | **No** — same dead E5 |

---

## On writing `CrownEusdBorrowUsdc.sol`

| Ask | Freeze answer |
|--|--|
| Write the contract? | **Yes — arm it** (supply/borrow/park/repayFor helpers). Canary only when `boss.liquidity ≥ size` **or** caller supplies USDC seed in-tx. |
| Update REPLAN to $1.9M C as Phase 2.5 wall-break? | **No** — do not encode eUSD→Aero→cbBTC as the filler. That reopens a killed path. |
| “Break tonight” with ocean only? | **No** — conservation unchanged. |

---

## Seat line

The wall **is** empty lenders on eUSD/USDC.  
Becoming the lender is correct **English** and wrong **funding**: you still need the first Circle (or blue-chip coll).  
Curator queue did its job; C-ocean cannot be the seed.  

**Next freeze lift:** ship `CrownEusdBorrowUsdc` as the **machine**, gate fire on real USDC seed or live boss liquidity — not on Elephant Brave swap fiction.
