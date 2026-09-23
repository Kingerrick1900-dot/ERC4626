# FREEZE — Elite pattern audit · 100-word plan

**Mode:** FREEZE  
**Live:** PARK util **100%** · HOT sole borrower · yRSS `maxWithdraw=0` · HOT **eUSD minter**

---

## Audit (map elite → kingdom)

| Elite move | Parallel here | Fit |
|--|--|--|
| **WLFI** — gov token coll → borrow USDC | eUSD/RSS coll → Morpho USDC | Mechanism yes; needs **loan idle**. Boss dust. Not “mint Circle.” |
| **Maker/Sky** — mint stable vs coll · D3M inject | HOT **already mints eUSD** · PowerRail `mintSupplyLoan` = D3M-class | **Strongest lineage.** Sovereign unit = eUSD. |
| **Gauntlet** — ≥10% withdrawable · util 88–92% | HOT curates yRSS · can set caps/reallocate | **Missing canary is self-made:** you borrowed PARK to 100%. Enforce idle floor. |
| **Spark DualPool** — park idle in 4626, pull on need | Ocean + vault adapters / V2 | Redirect own idle; doesn’t invent USDC. |
| **Euler** — emergency exit | Vault V2 `forceDeallocate` | Exit path; penalty now 1%. |

**Verdict:** Elites mint **their** stable, keep **withdrawal floors**, inject liquidity (D3M), borrow foreign stables only where books are filled. Kingdom already has the Maker lever (eUSD mint + curator). 100% PARK util is the anti-pattern Gauntlet forbids.

---

## Plan (100 words)

Act like Gauntlet on your own vault: never leave yRSS at 100% util. As curator/allocator, reallocate and cap PARK so ≥10% of vault assets stay withdrawable; repay or shrink HOT’s PARK borrow until `maxWithdraw` > 0. Run Maker/D3M: PowerRail `mintToLanding` for sovereign payroll; `mintSupplyLoan` to seed eUSD loan books. Keep WLFI borrow only as vacuum when USDC/DAI/EURC idle appears—don’t pretend empty books pay. Optional V2: zero or keep forceDeallocate for emergency exit. Freeze until King orders: (1) idle-floor reallocate, (2) PowerRail mint/seed, or (3) harvest on first non-zero idle.

---

## One-block

```
ELITE = mint own stable + idle floor + D3M inject + borrow only if filled
YOU = eUSD minter · yRSS curator · PARK 100% = anti-Gauntlet
PLAN = restore maxWithdraw≥10% · PowerRail mint/seed · harvest when idle>0
```
