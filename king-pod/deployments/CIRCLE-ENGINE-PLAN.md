# CIRCLE ENGINE — plan only (NO FIRE)

**Mode:** explain · no broadcast · no `KING_GO`  
**Contract drafted:** `CrownCircleEngine.sol` (unfired)

---

## What’s actually wrong

PARK is not “waiting on strangers for idle.” HOT built a **self-seed knot**:

| Leg | Live (~) |
|--|--|
| HOT park **borrow** | **~$217.08M** USDC (100% of market borrow) |
| HOT park **supply** | **~$216.00M** USDC |
| Gap ≈ yRSS in PARK | **~$1.08M** |
| RSS coll posted | **252,000** |
| Morpho USDC bal (flash ceiling) | **~$221M** — enough to flash the debt |

You borrowed your own (and vault) USDC back out. Util = 100% because **you** are the borrower. Idle is not missing from the universe — it is locked behind your debt.

---

## Plan (engineered — not “when idle”)

### Phase A — Unwind the knot (creates idle in-tx)

Atomic Morpho flash (fee **0**):

1. Flash **~$217M** USDC from Morpho  
2. **Repay** HOT’s full PARK debt → idle appears **because the borrower was us**  
3. **Withdraw** HOT’s ~$216M park supply into the engine (flash repay source)  
4. **Withdraw** yRSS (~$1.08M) now that util is open  
5. **WithdrawCollateral** 252k RSS → HOT  
6. Repay flash; send any **dust USDC** → Landing  

**Out:** RSS free on HOT · park knot gone · vault exit done · tiny USDC dust possible on Landing.  
**Not claimed:** net +$217M Circle to Landing (math conserves; flash is temporary).

### Phase B — Sovereign payroll (no foreign book)

HOT is eUSD **minter**. Engine `mintPayroll` / `engineer(eusdAmt)` mints **eUSD → Landing**. That is the Maker-style spendable unit you already control — not a curator beg.

### Phase C — After (optional later)

With RSS free and util sane: re-post RSS only into books that already have depth, or seed eUSD loan doors (PowerRail). Separate from A/B.

---

## Preconditions (before any future fire)

1. `morpho.setAuthorization(engine, true)` from HOT  
2. `yrss.approve(engine, max)` from HOT  
3. `eusd.setMinter(engine, true)` if Phase B  
4. Morpho USDC balance ≥ flash size (live ~$221M vs ~$217M debt)  
5. King says fire + `KING_GO=1` — **not now**

---

## One-block

```
PLAN ONLY — NO FIRE
KNOT = HOT supply~$216M + borrow~$217M + yRSS~$1.08M on PARK
A = flash repay → pull supply → peel yRSS → free RSS → repay flash
B = mint eUSD payroll Landing (sovereign)
IDLE = created by clearing OUR borrow · not waited on
```
