# Elepan BTC + ETH — $2 idle top-off (LIVE)

**Fired:** 2026-07-23 · King-directed ~$2 idle loan liquidity into each Morpho book.

## Result
| Market | Idle before | Idle after | ≈USD |
|--|--|--|--|
| Elepan/cbBTC | **0** | **3045** cbBTC (8dp) | **~$2** |
| Elepan/WETH | dust | **~0.001039 WETH** | **~$2** |

Sizing from Uni V3 spot at fire (~$65.7k BTC / ~$1.93k ETH).

## Txs (Base)
See `broadcast/TopOffElepanBtcEthTwoUsd.s.sol/8453/run-latest.json` (wrap WETH → approve → Morpho.supply ×2).

## Script
`script/TopOffElepanBtcEthTwoUsd.s.sol` — `KING_GO=1 FIRE_TOPOFF=1`
