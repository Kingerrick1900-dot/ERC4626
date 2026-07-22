# ELEPAN LEVERAGE LOOP — PHASE 3 (INTERNAL LENDER + BORROWER)

**Framing:** Collateralized leverage. King is **lender and borrower** on purpose — internal books, less confusion. Morpho-permitted. If outsiders never show, the loop still scales the bag.

## Plan text (~100 words)

Self-funded recursive leverage — locked as the no-external path: flash-loan → buy Elepan (or use bag) → supplyCollateral → borrow USDC → repeat, atomic via `onMorphoFlashLoan`. King is lender and borrower on the same Morpho stack so the kingdom still scales if depositors never arrive. Risk Controller enforces post-loop HF ≥1.55, soft LTV ≤70%, and max loop count before fire. Pair with forceDeallocate + flash exit for anytime self-del. Optional earn leg: park a slice of borrow in whitelist sinks only when borrow APR clears the spread gate; otherwise stay pure recursive on Elepan. Intent-logged. Ready when King says go — no babysitting each cycle.

## Caps
Soft LTV ≤70% · HF ≥1.55 · loops King-named (≤5) · $14M-class ask · no invented incentive APYs until listed on our market.
