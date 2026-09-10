# FREEZE — Audit: REPLAN-LEGAL-EDGE (canary $666k?)

**Mode:** FREEZE · plan not in repo yet · audited from the Majesty brief  
**Verdict:** **Not ready for canary.** Patches 1–2 (decimals, Safe) are real upgrades. Phase E5 still has **no legal USDC pipe**. Without E5, E1/Phase3 have no cbBTC.

---

## What the brief got right

| Patch | Audit |
|--|--|
| **cbBTC 8 decimals** (`2496000000` ≈ 24.96 BTC) | Correct vs e18 mistake. Size is **overkill** for $1.01M (≈**15.6 BTC** @ 95%×86% LLTV) but legally fine if coll exists. |
| **Safe = propose + 2 sigs** | Correct. No `--private-key` on Safe. |
| **`repay(onBehalf = borrower)` not “repay vault”** | Correct Morpho shape. Live: **HOT is sole park borrower** (borrow shares ≈ market). Unmatching = repay **HOT** debt → park idle opens → yRSS peels the deed. |
| Forbidden list | Aligns with crown doctrine (no ZK-write, no gasPark, no wash). |

**Note:** Live `CrownKingRail.p3PayrollWithCbbtc` already does this E1 shape: `repay(mpPark, amt, 0, king)` + `yrss.withdraw` + borrow cbBTC book. “repayFor” is naming, not a new law of physics.

---

## Hard kill — E5 ($2M eUSD → cbBTC)

Claim: ocean/eUSD → 3× **$666k** via KingRail → ~26 cbBTC.

| Check | Live |
|--|--|
| KingRail swap eUSD→USDC→cbBTC | **Does not exist.** Rail = P1–P4 Morpho/yRSS only. |
| Uni eUSD/USDC 100 | liquidity **0** · balances **127 wei** |
| Uni eUSD/USDC 500 | USDC in pool **6312** ($0.006) · eUSD dust |
| PSM / PSP USDC reserve | **0** · eUSD not a funded redeem |
| Canary `$666k` eUSD→USDC | **No counterparty USDC** — swap reverts or rugs into nothing |

**Seat:** E5 is still “militia currency → Circle” without a market. Decimals/Safe cannot create pool depth. **Canary $666k = no.**

---

## E1 — only after real cbBTC

```
borrow USDC on cbBTC/USDC (foreign ~$183M idle)
→ repay(onBehalf = HOT) on park
→ idle opens ≈ repay amt
→ yRSS.withdraw → Landing Circle
→ (optional) lasting idle via P4/puller if flash+supply path kept
```

Legal overcollateralized borrow: **yes**, if **24.96 BTC** (or ≥~15.6) is **already on HOT**.  
Stack today: HOT cbBTC = **1028 wei**. E1 cannot start from E5 fiction.

---

## Phase 3 — “flash rebalance unlocks $183M, no upfront”

Foreign book idle is **borrowable against collateral**, not a free vault.  
Flash coll swap / self-liq is legal **only** if end state respects LLTV and flash repay. It does **not** grant $183M to the kingdom without equity. Treat as optional **ops** after E1 coll exists — not a capital-free unlock.

---

## Pre-canary gates (freeze checklist)

| # | Gate | Status |
|--|--|--|
| G0 | REPLAN sheet landed in `king-pod/deployments/` with addresses | **Missing** |
| G1 | eUSD→USDC quote ≥ canary (pool/PSM) | **FAIL** |
| G2 | Or: cbBTC ≥ ~15.6 on HOT (skip E5) | **FAIL** (1028 wei) |
| G3 | Safe propose path on Base (no single PK) | Patch OK · not deployed |
| G4 | Success metric = Landing USDC ↑ or park idle ↑ | Define before lift |
| G5 | Wire to existing KingRail/Puller **or** justify new adapters | Not shown |

---

## Freeze doctrine (one line)

> **repayFor(HOT) unmatches the deed — correct.  
> eUSD chunks cannot buy the key — live DEX/PSM have ~$0 USDC.  
> Canary only when G1 or G2 is green.**

**Ready for canary $666k?** **No.**
