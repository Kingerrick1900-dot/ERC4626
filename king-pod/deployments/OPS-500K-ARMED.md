# Ops $500k — armed fires (no broadcast until KING_GO)

All paths below are scripted. Nothing goes live without `KING_GO=1` + the path flag.

| # | Fire | Flag | Needs at send | Lands |
|--|--|--|--|--|
| 1 | `FireElepanBills` / redeem draw | `FIRE_ELE_BILLS=1` | yELE balance on hot | USDC → Landing (post-cleanse redeem size) |
| 2 | `FireElepanBorrowUsdc` | `FIRE_BORROW=1` `BORROW_USDC=500000000000` | ELE/USDC idle ≥ ask | USDC → Landing |
| 3 | `FireMorphoOpsDraw` | `FIRE_MORPHO_OPS=1` | ELE/USDC idle ≥ ask | USDC → Landing |
| 4 | `FireZkCreditDraw` | `FIRE_ZK_CREDIT=1` `ASK_USDC=500000000000` | credit pool USDC > 0 | USDC → Landing |
| 5 | `FireMatcherComplete` | `FIRE_LOAN_MATCH=1` | `MATCHER_KEY` + matcher USDC | USDC → Landing atomic |
| 6 | `FireYeleShareExit` / `FireYeleShareExtract` | `FIRE_SHARE_EXIT=1` / `FIRE_YELE_SHARES=1` | buyer USDC or `TO=` / escrow | USDC → Landing |
| 7 | `FireOpsFive` cleanse+reallocate | `FIRE_OPS_FIVE=1` | yELE `acceptCap` WETH/USDC live | then redeem/borrow rails |
| 8 | WETH/USDC Morpho borrow | via `CrownOpsFive.borrowUsdcToLanding` | WETH coll on hot/ops | USDC → Landing (deep idle ~$7.7M) |

## Already on-chain (waiting)

| Item | Status |
|--|--|
| yELE `submitCap` WETH/USDC $50M | pending · unlock ~`1785092927` |
| yELE `submitTimelock` 1 day | pending · same window |
| After accept | reallocate ELE→WETH/USDC sink unlocks skim/redeem routing |

## Live meters (read-only)

| Meter | Value |
|--|--|
| Landing USDC | ~$10.37 |
| Credit `maxBorrow` | 0 (pool empty) |
| ELE/USDC idle | ~0 |
| WETH/USDC idle | ~$7.7M |
| yELE shares | almost all on Landing · dust on hot |

On `KING_GO=1` + path flag only — no other broadcast.
