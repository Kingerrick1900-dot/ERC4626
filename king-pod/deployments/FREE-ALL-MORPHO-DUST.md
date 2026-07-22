# FREE ALL — Morpho dust cleared to hot

**Status: LIVE SUCCESS** — King order: free all tokens to hot.

## Result

| Check | Before | After |
|--|--|--|
| Hot RSS | ~13.03M | **~14.03M** |
| Morpho coll | 1.00M RSS | **0** |
| Morpho debt | ~$1.0005 | **0** |
| Hot USDC | $0 | ~$0.057 leftover |
| Hot ETH | ~0.00060 | ~0.00015 (gas + swap) |

## How

1. Wrap/swap ~0.00055 WETH → USDC via UniV3 (fee 500) on Base  
2. `repay` Morpho dust shares — tx `0x818ed85d…2fcb4f`  
3. `withdrawCollateral` 1M RSS — first attempt OOGed (`0xa36c7a52…`); retry succeeded — tx `0xf351ff08…409a125f`

## Script

`king-pod/script/FireFreeAllMorphoDust.s.sol` (`KING_GO=1 FREE_ALL=1`)

## Still not freeable (known)

| Bag | Why |
|--|--|
| KingPair V1 ~20.9815B RSS | No `releaseCollateral` — stuck in V1 Market LP |
| Dust yRSS shares | ~$0.35 face; `maxWithdraw=0` / illiquid — not Morpho coll |

## Comfort Throne

Still **HOLD** — no re-lock until King tweaks plan. All freeable Morpho RSS is now on hot.
