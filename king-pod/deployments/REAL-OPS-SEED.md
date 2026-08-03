# REAL OPS SEED — desk-free, using what King holds

**Mission:** Seed the nation — pay ops + reinvest. No desk-wait as primary.  
**Status:** FIRED LIVE (Base) — ONCHAIN SUCCESS  
**Override:** `KING_OVERRIDE_NO_RECYCLE=1` used on King fire order.

## Live fire (2026-08-03)

| | |
|--|--|
| Seeder | `0xBAe84DB68b444f87593ec76225CF63A33d502532` |
| opsSeed tx | `0x36bf09b3e62b7d9e189493c20c0fac719fff6a7bb3beb8c4a16e265fd0d0df85` |
| Size | **$700,000** USDC |
| yRSS TVL after | **~$700,000.03** |
| hot yRSS assets | **~$700,000.03** |
| RSS coll posted | **~15.03M** (hot free RSS = 0) |
| Morpho debt | ~$700k (borrow shares live) |
| Elepan | **untouched** (~44.6M free) |
| Liquid USDC | ~0 (flash closed — as designed) |
| maxWithdraw | **0** (100% util — exit still required for payroll USDC) |

## Capital allocation fix (same session)

Posted **all 15.03M** on first fire was oversized for a $700k seed. Excess withdrawn:

| | |
|--|--|
| withdrawCollateral tx | `0xa00167aad3ad136e54b679af97451d65ea082b8e27ebc3163de6a3d9a4dc8a81` |
| Freed to hot | **~13.83M RSS** |
| Still posted | **1.2M RSS** |
| Debt | $700k |
| LTV after | **~58.3%** (under 70% soft / 77% LLTV) |

Rule going forward: size coll to ask (+ small buffer), keep treasury free.


## What we have (live)

| Asset | Amount | Role |
|--|--|--|
| True RSS on hot | **~15.03M** | Collateral bait |
| Elepan on hot | ~44.6M | **Stays free** |
| RSS market idle | ~$1 | Empty until we self-fund |
| yRSS TVL | ~$0.35 | Empty war chest |
| WETH/cbBTC Morpho idle | huge | **Unusable** — hot has no WETH/cbBTC |
| Empire liquid USDC | ~$0–1 | Not enough |

## The engineered path (no desk)

Same machine that already fired $9M once — sized to **$600k–$700k**:

1. Post RSS collateral  
2. Morpho **flash** USDC  
3. `yRSS.deposit` → USDC hits RSS market (idle appears)  
4. `borrow` against RSS → repay flash  

**One transaction. No Armitage. No RFQ.**

| End state | Fact |
|--|--|
| yRSS on hot | ≈ **$600k–$700k** assets (reinvest / fee rail) |
| Morpho debt | same size |
| RSS | posted as collateral |
| Liquid USDC (hot/Landing) | **~$0** after flash closes |
| Elepan | untouched |

That is a **real onchain seed** (war chest + 10% fee → KingVault). It is **not** payroll USDC in the Landing wallet until an **exit** exists (`maxWithdraw` is 0 at 100% util).

## Honesty split

| Need | This path |
|--|--|
| Reinvest / treasury TVL / fee rail | **YES** — yRSS |
| Spendable ops USDC on Landing this tx | **NO** — flash closes flat |
| Desk signature | **NO** |

Liquid Landing payroll is a **second** engineering problem (exit / convert / external idle). King said no excuses — this ships the desk-free seed that physics allows **with RSS alone** first.

## Fire (King only)

```bash
cd king-pod
# Prep deploy + auth (no seed)
KING_OVERRIDE_NO_RECYCLE=1 FIRE=0 PRIVATE_KEY=… \
  forge script script/FireRssOpsSeed.s.sol:FireRssOpsSeed \
  --rpc-url $BASE_RPC --broadcast --slow

# Fire $700k (or BORROW_USDC=600000000000)
KING_OVERRIDE_NO_RECYCLE=1 FIRE=1 BORROW_USDC=700000000000 PRIVATE_KEY=… \
  forge script script/FireRssOpsSeed.s.sol:FireRssOpsSeed \
  --rpc-url $BASE_RPC --broadcast --slow
```

## Next after seed (liquid ops)

Only after war chest exists: engineer **exit** (forceDeallocate / external idle into RSS / King-authorized convert) so `maxWithdraw` > 0 and USDC can hit Landing for ops.

## Contracts

| | |
|--|--|
| `CrownRssOpsSeed` | `src/CrownRssOpsSeed.sol` |
| Fire script | `script/FireRssOpsSeed.s.sol` |
| Packet | `rss-ops-seed.json` |
