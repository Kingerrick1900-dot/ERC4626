# HANDOFF — King's Combined Plan

**Mode:** LAW · ZK + Quantum enforced · PR #195  
**Doctrine:** `ZK_SHIELD=1` · no transparent path · `isProven(HOT)` on every fire

---

## The Split

| Borrow | Amount | Purpose | Routing |
|--|--:|--|--|
| **#2 Engine** | $1,000,000 | Yield deployment | Yield venue (Steak / Gauntlet via `CrownZkYieldLadder`) |
| **#1 Reserve** | $1,000,000 | Payroll + Kingdom reserve | HOT |
| **Total new** | **$2,000,000** | | |
| Existing | $1.1M | Gate $1.0M + Credit $100k | Live |
| **Position target** | **$3.1M** | vs 222,521.94 RSS @ $50k | |

---

## Secure (live)

| Check | Result |
|--|--|
| Gate | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| Collateral | **222,521.94 RSS** |
| Oracle | CrownOracle `0x22E2…` **$50,000** |
| Coll value | **~$11.13B** |
| Pre-fire debt | ~$1.1M · LTV **~0.01%** · LLTV 77% |
| `isProven(HOT)` | **true** · WalletGate `0x3fF6…7091` |

---

## Sequence

1. **Secure** — collateral healthy (above)  
2. **Fire Borrow #2** — $1M engine → yield ladder / Morpho yield book (ZK)  
3. **Fire Borrow #1** — $1M reserve → HOT (ZK)  
4. **Monitor** — LTV, accrual, repay schedule  
5. **Repeat** — scale idle markets  

Script: `script/FireKingsCombined.s.sol` · `FIRE_KINGS_COMBINED=1` · `ZK_SHIELD=1`  
Contract: `src/zk/CrownKingsCombinedFire.sol`

---

## Doctrine locks

| Rule | Enforcement |
|--|--|
| ZK every fire | `ZK_SHIELD=1` · `TRANSPARENT_OK`/`NO_ZK` abort |
| Proven King | `zkGate.isProven(king)` |
| Gate borrow | `CrownGateV2` · `whenZkFire` |
| Yield path | `CrownZkYieldLadder` · Steak 60% / Gauntlet 40% |
| Oracle | King-only `CrownOracle.setPrice` |

```
HANDOFF=KINGS_COMBINED_PLAN
ZK_SHIELD=MANDATORY
BORROW_ENGINE=1000000e6
BORROW_RESERVE=1000000e6
COLLATERAL_RSS=222521.94
```
