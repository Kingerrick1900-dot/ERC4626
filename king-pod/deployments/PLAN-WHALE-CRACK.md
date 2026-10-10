# PLAN — Whale Crack: Sole-Borrower Edge + Parallel Capacity

**Status:** Recorded · Endorsed · Reconnaissance **PUBLISHED**  
**Mode:** READ / estimate · **no fire**  
**Base block:** **52277337**  
**Mandate:** Zero external capital · RSS never sold · no counterparties · dust only · live path or prove frozen

---

## Mandate (locked)

- Zero external capital  
- RSS never sold  
- No counterparties  
- Dust only  
- Produce a live path — or prove the position permanently frozen  

---

## Decision tree

```
Dust repay + withdrawCollateral succeeds @ 100% util?
├── Yes → Free max RSS with available dust → parallel market → borrow → rebuild USDC
└── No  → Position frozen → parallel market only → accumulate dust/yield until real repay
```

Critical empirical test: **does `repay` + `withdrawCollateral` succeed for the sole borrower at 100% utilization?**  
Smallest repay ($1–10) via King-controlled `SoleBorrowerHelper` (authorized by Gate).

---

## Recon 1 — Gate position on `0x1293…`

Market: `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b`  
Gate: `0x76fa390951fA31185490378F46B6e9F05bA4bC3b`

| Field | Exact value |
|--|--|
| `supplyShares` | **`0`** |
| `borrowShares` | **`2999964634431372816`** |
| `collateral` (RSS wei) | **`222521940922706875000000`** (= 222,521.940922706875 RSS) |
| Accrued borrow assets (sole) | **`3002050049190`** (~$3,002,050.05) |
| Market liquidity | **`0`** (100% util) |
| Other borrowers | **none** — Gate is sole borrower (100% of borrow shares) |

Note: Morpho Blue has **no collateral shares** — collateral is raw asset units.

```
GATE_SUPPLY_SHARES=0
GATE_BORROW_SHARES=2999964634431372816
GATE_COLLATERAL=222521940922706875000000
GATE_BORROW_ASSETS~=3002050049190
SOLE_BORROWER=true
```

---

## Recon 2 — Dust sweep (USDC / ETH)

Kingdom-controlled + deploy wallets · Base · block 52277337

| Name | Address | USDC (6dp) | ETH (wei) |
|--|--|--:|--:|
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | **164417** | 8586105149509 |
| ColdBuffer | `0xBb3c14bBacD639797cB5c537fde370d1b7195521` | **294101** | 0 |
| DeepPull | `0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A` | **697192** | 0 |
| Landing (Safe owner) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` | 0 | 24651427933949 |
| NEW_COLD (Safe owner) | `0x5E07D7167282F9ec912a05c3048D7D0F24A8b826` | 0 | 12991777731907 |
| Safe | `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0` | 0 | 0 |
| Safe owner3 | `0x898DbAFfCD37298a60Fd306e5D1B24fE16C12507` | 0 | 0 |
| Gate / Credit / fires / armor / oracle / attest | (see scan) | 0 | 0 |
| WETH all scanned | — | — | **0** |

| Total | Value |
|--|--:|
| **USDC sum** | **1,155,710** (~**$1.16**) |
| **ETH sum** (HOT+Landing+NEW_COLD) | **46,229,310,815,365** wei (~**0.04623 ETH**) |
| USDC for dust repay (HOT+Cold) | **458,518** (~$0.46) |
| USDC if DeepPull sweepable | **+697,192** → ~$1.16 total |

**Fuel verdict:** Dust exists for a **$1–$1.16** test repay. Not enough to clear the ~$3.00M book. Enough to run the empirical crack test.

```
DUST_USDC_TOTAL=1155710
DUST_ETH_WEI=46229310815365
REPAY_TEST_FUEL_USD~=1.16
```

---

## Recon 3 — Gas budget (test repay + parallel market)

| Step | Gas estimate | Basis |
|--|--:|--|
| SoleBorrowerHelper deploy | 1,200,000 | ~CombinedFire deploy hist `1,181,403` |
| Morpho `createMarket` (parallel) | 250,000 | hist sovereign create `197,613` + buffer |
| Gate `setOperator` / auth | 100,000 | typical |
| Dust `repay` via Gate | 250,000 | Morpho repay + Gate |
| `withdrawCollateral` | 180,000 | Morpho withdraw |
| **Core subtotal** | **1,980,000** | |
| **+30% buffer** | **594,000** | |
| **Total budget** | **2,574,000 gas** | |

| Cost @ live gas price | Value |
|--|--|
| `gas-price` | **6,000,000 wei** (6 gwei) |
| ETH cost | **~0.00001544 ETH** (~**$0.04** @ $2,500/ETH) |
| Kingdom ETH on hand | **~0.046 ETH** |

**Gas verdict:** **CONFIRMED** — dust ETH covers the full test + parallel deploy budget by >1000×.

```
GAS_BUDGET=2574000
GAS_PRICE_WEI=6000000
ETH_COST~=0.00001544
ETH_ON_HAND~=0.04623
GAS_OK=true
```

---

## What this unlocks next (still no fire until commanded)

1. Build `SoleBorrowerHelper` (King/Safe-controlled).  
2. Simulate: dust repay ($1) + `withdrawCollateral` at 100% util.  
3. Branch on empirical result per decision tree.

```
PLAN=WHALE_CRACK
RECON=DONE
BORROW_SHARES=2999964634431372816
COLLATERAL=222521940922706875000000
DUST_USDC=1155710
GAS_BUDGET=2574000
FIRE=NO
NEXT=BUILD_SOLE_BORROWER_HELPER_SIM
```
