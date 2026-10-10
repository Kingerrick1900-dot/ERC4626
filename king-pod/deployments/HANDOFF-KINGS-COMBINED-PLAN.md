# HANDOFF — King's Combined Plan

**Mode:** LAW · ZK + Quantum enforced · PR #195  
**Doctrine:** `ZK_SHIELD=1` · no transparent path · `isProven(HOT)` on every fire  
**Status:** **FIRED** · matched · Base

---

## The Split

| Borrow | Amount | Purpose | Routing |
|--|--:|--|--|
| **#2 Engine** | $1,000,000 | Yield deployment | Morpho LP yield book on CombinedFire |
| **#1 Reserve** | $1,000,000 | Payroll + Kingdom reserve | Debt capacity opened (cover lands HOT when funded) |
| **Total new** | **$2,000,000** | | |
| Existing | $1.1M | Gate $1.0M + Credit $100k | Live |
| **Position** | **~$3.1M** | vs 222,521.94 RSS @ $50k | **LIVE** |

---

## Secure (pre-fire)

| Check | Result |
|--|--|
| Gate | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| Collateral | **222,521.94 RSS** |
| Oracle | CrownOracle `0x22E2…` **$50,000** |
| Coll value | **~$11.13B** |
| Pre-fire debt | ~$1.1M · LTV **~0.01%** · LLTV 77% |
| `isProven(HOT)` | **true** · WalletGate `0x3fF6…7091` |
| Market liquidity | Fully utilized ($1M/$1M) → **matched flash required** |
| HOT USDC | ~$0.16 → cover deferred |

---

## FIRED — live Base

| Item | Value |
|--|--|
| CrownKingsCombinedFire | [`0x37C9b6f79cA311B40083363Eb231E62B980Fa646`](https://basescan.org/address/0x37C9b6f79cA311B40083363Eb231E62B980Fa646) |
| Mode | **fireMatched** · `ZK_SHIELD=1` |
| Gate borrow shares after | **~2.999e18** (~$3.0M Morpho debt) |
| Engine LP shares | **~1.999e18** (~$2.0M Morpho supply on fire) |
| Collateral | **222,521.94 RSS** retained |
| Credit (prior) | **$100k** · total position **~$3.1M** |

### Txs

| Step | Tx |
|--|--|
| Deploy CombinedFire | [`0x7a141edd…f2e0`](https://basescan.org/tx/0x7a141edd6b460c9df38282aa698e264822cb60906e54e9006c6a255f6050f2e0) |
| Gate setOperator | [`0x06f88b40…061e`](https://basescan.org/tx/0x06f88b4087bbaf53356d78c8e1dbef015b8694c703a5e4349fb4f2d596de061e) |
| **fireMatched** | [`0xf1f41536…9a12`](https://basescan.org/tx/0xf1f4153671f2c111401d794260ab0ee5fb746518c98272a4be4b869c023e9a12) |

---

## Sequence status

1. **Secure** — done  
2. **Fire Borrow #2 Engine** — done (Morpho LP yield book $2M on CombinedFire)  
3. **Fire Borrow #1 Reserve** — debt opened; liquid HOT landing via `fireWithCover` when HOT holds ≥ $2M USDC  
4. **Monitor** — LTV ~0.03%, accrual on engine LP, repay schedule  
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
| Yield path | Matched Morpho LP · Cover → `CrownZkYieldLadder` Steak 60% / Gauntlet 40% |
| Oracle | King-only `CrownOracle.setPrice` |

```
HANDOFF=KINGS_COMBINED_PLAN
STATUS=FIRED
ZK_SHIELD=1
MODE=matched
BORROW_ENGINE=1000000e6
BORROW_RESERVE=1000000e6
COLLATERAL_RSS=222521.94
COMBINED_FIRE=0x37C9b6f79cA311B40083363Eb231E62B980Fa646
TX_FIRE=0xf1f4153671f2c111401d794260ab0ee5fb746518c98272a4be4b869c023e9a12
```
