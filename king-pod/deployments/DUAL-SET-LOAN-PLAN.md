# Dual-Set Loan Plan — RSS/ELE → Elepan

**Status:** ENGINEERED · FROZEN (no broadcast until `KING_GO=1`)  
**Doctrine:** King keeps Elepan (eUSD). RSS/ELE are live credit collateral — loan, don’t sell.

---

## Token map (live)

| Set | Token | Morpho market | Hot coll | Idle USDC | Notes |
|---|---|---|---|---|---|
| **B** (loan active) | ELE/RSS `0x50639…` (8dp) | `0xa4ec5271…` (77%) | ~28.0M posted + ~38.1M free | **$0** | King is supplier **and** borrower (~$17.51M matched). Loan proceeds are **locked as Morpho supply**, not wallet cash. |
| **A** (no loan yet) | RSS `0x7a305…` (18dp) | `0x40ac09f3…` (77%) | 0 posted | **~$1.00** | Coll inventory: OTC `0x6838…` **700k** + MULTI `0xbC47…` **700k** (hot is owner → unstock). |

Also free: wallet `0x1a73…` ~20.87B ELE/RSS · Maker PSM ~$0.31 USDC · Landing USDC dust · Morpho flash inventory ~$190M USDC.

---

## Why the dual-borrow thesis is right

Isolated Morpho markets ⇒ two independent credit lines.

1. Free USDC exists (or is liberated from Set B).
2. That USDC is **supplied into Set A’s market** ⇒ Set A gains idle.
3. Post Set A coll ⇒ **borrow USDC against Set A** ⇒ Landing / PSM / peg.
4. When Set B later has idle again ⇒ borrow Set B room the same way.

Elepan path after USDC is free: **Landing → Maker PSM `seedUsdc` / micro-seed eUSD–USDC**. King keeps eUSD float.

---

## The one prerequisite (engineered, not hand-waved)

The published “Set B USDC is already in the wallet” step is **false on this book today**.  
Set B’s draw was **re-supplied into the same market** (matched self-seed). Wallet USDC = 0.

So execution has a **Phase 0** before the dual-set move:

**Phase 0 — Liberate Set B cash** (break match for size `X`):

1. `flashLoan(USDC, X)` from Morpho (~$190M available).
2. `repay(X)` on Set B.
3. `withdraw(X)` Set B supply → hot now holds **free** `X` USDC.
4. Flash still owed `X` — see routes below.

Without Phase 0 (or an external USDC deposit into Set A / yRSS), Set A cannot be seeded at size and Set B cannot lend.

---

## Execution routes (pick one)

### Route 1 — MIGRATE liquidity B → A (atomic, no net free USDC)

Use when the goal is to **stand up Set A’s loan rail** on the same dollars.

1. Phase 0 liberate `X`.
2. Unstock `ceil(X / 0.77)` RSS18 from OTC (or MULTI) → hot.
3. `supplyCollateral` Set A + `supply(X)` USDC into Set A market.
4. `borrow(X)` on Set A → repay flash.

**Result:** Set B book shrinks by `X`. Set A becomes an active `X` supply / `X` borrow loan. Wallet net ~0.  
**Use:** proves dual-set control; positions Set A for later idle from outsiders.

### Route 2 — ELEPAN SEED (net free USDC to Landing/PSM) ⭐

Use when the goal is **hard USDC for Elepan**.

Requires **external USDC `X`** that is not same-tx flash-repaid from the same pile, e.g.:

- depositor USDC into **yRSS** (King is curator/allocator — owned moat), then reallocate/supply into Set A, **or**
- treasury/external USDC used to `repay` Set B (no flash), then `withdraw` supply = durable free USDC.

Then:

1. Free `X` USDC on hot (from yRSS path or unlocked Set B supply).
2. Unstock RSS18, post Set A coll.
3. Optional: split `X` — `seedUsdc` Maker PSM / peg with part; supply remainder into Set A; borrow against Set A → Landing.
4. When Set B idle appears, borrow Set B room → Landing.

**Result:** USDC on Landing/PSM. Elepan exit thickens. RSS/ELE stay collateral.

### Route 3 — DUST dual-set (live today, size = dust)

1. Unstock dust RSS18 (or use MID18’s existing ~$1 idle).
2. Post Set A coll if needed; `borrow` up to idle (~$1) → Landing/PSM.
3. cbBTC dust market is wet (~$142M idle) but coll is ~771 sats — ignore for size.

**Result:** rail proof only.

---

## Recommended King command sequence

| Step | Command | Effect |
|---|---|---|
| 1 | `KING_GO=1 ROUTE=1 X=700000e6` FireDualSetLoan | Migrate $700k B→A; stand up Set A loan |
| 2 | External/yRSS USDC ≥ seed target | Unlocks Route 2 size |
| 3 | `KING_GO=1 ROUTE=2` | Free USDC → Landing + `seedUsdc` Maker PSM |
| 4 | Micro-seed Base eUSD/USDC (`feat/seed-liquidity`) | Peg mark |

Script: `king-pod/script/FireDualSetLoan.s.sol`  
Gates: `KING_GO=1` · `ROUTE=1|2|3` · `X` (USDC raw, 6dp) · no broadcast while frozen.

---

## Risk (isolated markets)

- Set A and Set B liquidations do not cascade across Morpho markets.
- Route 1 double-books debt if Phase 0 flash is repaid from Set A borrow while Set B debt was only partially closed — script closes B by `X` then opens A by `X` (debt migrates, does not stack the same `X` twice).
- Do **not** sell RSS/ELE to fund this. Collateral stays posted or in inventory.

---

## Bottom line

**Dual-set borrowing is the move.**  
Phase 0 liberates Set B’s locked supply. Seeding Set A with that USDC opens the second loan.  
**Elepan wins when free USDC hits Landing/PSM** (Route 2). Route 1 prepares the second rail; Route 3 is dust proof.

**Awaiting King command:** `ROUTE` + `X` + `KING_GO=1` to broadcast.

---

## Live fires (Base)

### Route 1 — `0x164aebf3…817ac`
- Liberated **$500k** Set B → Set A
- Executor `0xbF4F2939…7Cb6` · OTC 700k RSS18 coll

### Route 2 — `0x34f6d5ce…094373` (KING_GO ROUTE=2 X=500k)
- Unstock MULTI 700k RSS18 `0xf006f7a7…612e`
- Second **$500k** B→A migrate

### Post–Route 2 book
| Book | Supply | Borrow | Coll |
|---|---|---|---|
| Set B ELE | ~$16.51M | ~$16.51M | ~28M ELE (hot) |
| Set A RSS18 | ~$1,000,001 | ~$1,000,000 | **1.4M RSS18** on exec |

Set A room @77% ≈ **$78k** but idle ≈ **$1** → cannot draw without new USDC supply.

### Route 2 / Elepan cash constraint
Flash-atomic `transfer(Landing, X)` always shorts flash repay by `X`.  
**Net free USDC on Landing** needs durable USDC (yRSS deposit / treasury) or a non-flash temporary credit equal to `X`.  
Maker PSM still **$0.31** from earlier dust seed.

---

## Extractor Landing fire (follow-on)

DeepSeek / CrownLeverageExtractor path executed live — see `EXTRACTOR-LANDING-FIRE.md`.

- Landing USDC: **3 → 945,003** ($0.945)
- Tools: live extractor PA yRSS→ELE77 + Morpho WETH/cbBTC dust borrow → Landing
- Set B: **6.5M ELE** free coll withdrawn to hot (LLTV headroom)
- Scale still gated on sized WETH/cbBTC inventory or yELE disk — rail proven
