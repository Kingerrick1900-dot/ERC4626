# CAPACITY — Sovereign loan upgrade (no fire)

**Mode:** READ · Base block **52242812** · UTC **2026-10-06T08:22:51Z**  
**Command:** Do not fire. Report max borrow capacity and who supplies.  
**Market:** `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b`  
**Gate:** `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` · King Safe · Operator HOT · ZK proven

---

## Verdict

| Question | Answer |
|--|--|
| Collateral headroom @ 77% LLTV | **~$8.56 billion** remaining |
| Lendable idle USDC in market | **$0** |
| **Max additional Morpho borrow now** | **$0** |
| Credit additional borrow | **$0** (pool fully drawn) |
| Who supplies the USDC | Kingdom fire contracts (matched seed) — see below |

The King can borrow more against the same 222k RSS **only after new USDC is supplied** into this market (or Credit is reseeded). Collateral is not the constraint. Liquidity is.

---

## 1) Live books

| Meter | Raw | USD |
|--|--:|--:|
| Morpho supplyAssets | `3000895191476` | ~$3,000,895 |
| Morpho borrowAssets | `3000895191476` | ~$3,000,895 |
| **liquidityAssets (idle)** | **0** | **$0** |
| Gate collateral | `222521940922706875000000` RSS | 222,521.94 RSS |
| Oracle `price()` | `5e28` | **$50,000 / RSS** |
| Collateral value | — | **~$11.126B** |
| Max borrow @ 77% LLTV | — | **~$8.567B** |
| Current Gate Morpho debt | — | **~$3.0009M** |
| LTV | — | **~0.027%** |
| Credit `totalSupplyUsdc` / `totalDebt` | `100000010278` | ~$100,000 / fully drawn |
| Credit `maxBorrow(HOT\|Safe)` | `0` | $0 |

---

## 2) Max borrowing capacity

```
coll_max     = coll_value × 77%     ≈ $8,567,094,725
liquidity    = supply − borrow      = $0
credit_idle  = supply − debt        = $0

max_additional_morpho = min(coll_max − debt, liquidity) = $0
max_additional_credit = $0
max_additional_total  = $0
```

Risk-lock cross-check (`ORDER-PROCEED-ELEPHANT` Item 4):  
`min(idle×50%, LLTV×coll×85%)` with idle=0 → **$0**.

---

## 3) Who is the supplier

`supplyingVaults` = **none**. Two EOAs/contracts hold **100%** of Morpho supply shares:

| Rank | Address | Role | Supply ~USD | Shares |
|--:|--|--|--:|--|
| 1 | `0x37C9b6f79cA311B40083363Eb231E62B980Fa646` | **CrownKingsCombinedFire** (owner/king = HOT) | **~$2,000,545** | `1999964634431372815` |
| 2 | `0x16a3a6d50e80D70C873645789afCECf8B8b6aDC9` | **CrownKingsFire** (owner/king = HOT) | **~$1,000,290** | `1000000000000000000` |

Borrower (all debt): **CrownGateV2** `0x76fa…` · ~$3.0009M · collateral 222,521.94 RSS.

### How the supply got there (matched fires)

| Tx | Supplier | Supply | Gate borrow |
|--|--|--:|--:|
| [`0x5e0514f9…d641`](https://basescan.org/tx/0x5e0514f969bff734615886c2da1039893154553a8a555614bfa6d54dd93dd641) | CrownKingsFire | **$1,000,000** | **$1,000,000** |
| [`0xf1f41536…9a12`](https://basescan.org/tx/0xf1f4153671f2c111401d794260ab0ee5fb746518c98272a4be4b869c023e9a12) | CrownKingsCombinedFire | **$2,000,000** | **$2,000,000** |

These were **flash-matched seeds**: supply USDC → Gate borrows same size → flash repaid. The fire contracts **remain Morpho LPs** (supply shares). The Gate **holds the debt**. Net new external USDC to the Kingdom wallet from those legs was not left as idle in the market — idle stayed **$0**.

USDC balances on both fire contracts today: **0**.

---

## 4) What a “larger loan” requires (still no fire)

Same market · same collateral · same Gate. To raise Morpho debt above ~$3.0M:

1. **Someone supplies fresh USDC** into market `0x1293…` (external LP, cover USDC on HOT via `fireWithCover`, or another matched seed that leaves net liquidity).  
2. Then Gate/`borrowUSDC` can draw up to `min(new_idle, coll_headroom, risk locks)`.  
3. Credit larger loan separately needs **USDC deposited into** `CrownZkCredit` `0x7527…` (currently empty of free cash).

Without new supply, **max additional borrow = $0**. No cbBTC. No new market. The engine is live; it is out of fuel.

---

```
CAPACITY=SOV_LOAN_UPGRADE
IDLE_USDC=0
MAX_ADDITIONAL_MORPHO=0
MAX_ADDITIONAL_CREDIT=0
COLL_HEADROOM_USD~=8564093830
SUPPLIER_1=0x37C9b6f79cA311B40083363Eb231E62B980Fa646:CrownKingsCombinedFire:~2M
SUPPLIER_2=0x16a3a6d50e80D70C873645789afCECf8B8b6aDC9:CrownKingsFire:~1M
BORROWER=0x76fa390951fA31185490378F46B6e9F05bA4bC3b:CrownGateV2:~3.0009M
FIRE=NO
NEXT=NEED_NEW_USDC_SUPPLY_INTO_0x1293
```
