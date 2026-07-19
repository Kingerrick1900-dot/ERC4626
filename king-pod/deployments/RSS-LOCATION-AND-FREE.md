# RSS location map + free status (Base)

Live read confirms **all 21,000,000,000 RSS** is accounted for. Nothing is missing.

## Where the tokens are

| Amount | Location | Status |
|--------|----------|--------|
| **20,981,500,000 RSS** | KingPair V1 `0x56ebfc0af28e1a9d8e6f9d0f3262ff1ad1a78f8c` | **Stuck** — LP held by Market V1 `0x50a61ca6…2578`; `debtUsdc(king) = $170,000`; V1 has **no** `releaseCollateral` |
| **18,500,000 RSS** | Morpho Blue collateral (king `0x6708…a7d1`) | **Freeable** — locked against **$9,000,000** borrow; USDC supply sits in **yRSS** `0xF80C…D525` (king owns ~100% shares) |
| **0 RSS** | King hot wallet | expected while Morpho book is open |

## Why hot does not hold the 21M liquid slice

The intended liquid bag was **21,000,000 RSS**. That slice was posted as Morpho collateral and scaled into the **$9M self-seed** (borrow USDC → deposit yRSS). Hot balance went to **0**; Morpho holds **18.5M** as collateral.

The other **~20.9815B** never left V1 LP from bootstrap.

## Free path A — Morpho 18.5M (proven on fork)

Existing freer `0x50D9…6418` reverts `Short()` on the current book because:

1. King Morpho `supplyShares = 0` (USDC is in yRSS, not direct Morpho supply)
2. After repay, yRSS can return ~$9,000,975 but flash repayment needs ~$107 more (share/fee rounding)

**Fix:** new freer + **$500 USDC prefund on hot**, then:

```bash
cd king-pod
PRIVATE_KEY=<hot 0x6708… key> forge script script/DeployAndFreeRss.s.sol:DeployAndFreeRss \
  --rpc-url $BASE_RPC --broadcast
```

Fork test `test_free_with_prefund` passes: Morpho debt/coll → 0, hot receives **~18.5M RSS**.

## Free path B — V1 pair 20.9815B

**Not freeable with current V1 bytecode.** Market holds the LP; no exit/release. Paying the $170k debt mapping does not unlock LP without `releaseCollateral`. V2 does not migrate V1 LP.

## This cloud agent

No `PRIVATE_KEY` in environment — cannot broadcast the free tx from here. King (or VPS with hot key) must run DeployAndFreeRss after funding hot with **≥ $500 USDC** for gas gap cover (hot currently has ~$1 USDC + ~0.0047 ETH).
