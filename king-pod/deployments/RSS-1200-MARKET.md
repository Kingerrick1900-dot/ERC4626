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

## Oracle freeze

`MorphoFrozenFixedOracle` — `priceValue` is `immutable`. No `setPrice`. No owner.

## OWN-CAPITAL FREEZE (King order — day one)

**Do not use other people’s capital.** See `OWN-CAPITAL-ONLY-FREEZE.md`.

| Status | |
|--|--|
| Market | Created — **tooling only** |
| NAV / `supply(onBehalf=yRSS)` / flash-donation redeem | **FORBIDDEN — dead** |
| Enable on yRSS / PA routing into this market for foreign books | **FORBIDDEN while freeze holds** |
| Clean path (when King lifts + seeds) | King USDC seed → King RSS collateral → Morpho borrow → Landing |

USDC to Landing = **loan from own seeded liquidity against own assets.** Not vault NAV surplus. Not third-party idle. Not automated routers.

## Next

**Sit.** See `LOANS-TO-OPS-WALL-FREEZE.md`. This market is empty tooling — capacity ≠ cash. No desk-hope.
