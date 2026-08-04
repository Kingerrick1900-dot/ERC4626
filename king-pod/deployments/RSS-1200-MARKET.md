# RSS / USDC Morpho market — frozen $1200 oracle

**LIVE Base.** RSS only. Elepan never touched. Oracle immutable (no admin).

| | |
|--|--|
| Market ID | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| Oracle | `0xB5840644142B341a6145335e2ebc82EEBC7aE1B9` |
| Price | **$1200** / RSS (`1200e24` Morpho scale) — **frozen** |
| Collateral | True RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** |
| Deploy oracle | see `broadcast/FireRss1200Market.s.sol/8453/` |
| Create market | same broadcast |

## Freeze

`MorphoFrozenFixedOracle` — `priceValue` is `immutable`. No `setPrice`. No owner.

## Next (position)

Enable on yRSS · supply / supplyCollateral · borrow to Landing when liquidity is live.
