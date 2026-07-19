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

## Free path A — Morpho 18.5M (proven on fork, $0 USDC prefund)

**Use chunk free (preferred):** no $500 needed. Leaves ~$300 dust debt + ~400 RSS posted.

```bash
cd king-pod
PRIVATE_KEY=<hot 0x6708… key> forge script script/DeployAndChunkFreeRss.s.sol:DeployAndChunkFreeRss \
  --rpc-url $BASE_RPC --broadcast
```

Fork test `test_chunk_free_to_king_no_prefund` passes: **~18.5M RSS → hot only**.

**Hard rule after free:** do **not** recycle into Morpho/yRSS/Pod until a tested exit exists (`NO-RECYCLE-UNTIL-EXIT.md`). Self-seed scripts are `revert` frozen.

## Free path B — V1 pair 20.9815B

**Not freeable with current V1 bytecode.** Market holds the LP; no exit/release. Paying the $170k debt mapping does not unlock LP without `releaseCollateral`. V2 does not migrate V1 LP.

## This cloud agent

No `PRIVATE_KEY` in environment — cannot broadcast the free tx from here. King (or VPS with hot key) must run DeployAndFreeRss after funding hot with **≥ $500 USDC** for gas gap cover (hot currently has ~$1 USDC + ~0.0047 ETH).
