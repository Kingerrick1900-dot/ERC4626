# Outside kingdom — live $700k+ USDC doors (Base Morpho)

Scanned Morpho Blue + PA outside ELE books. Liquidity exists. Kingdom hot holds **none** of the required collateral today.

## Live external doors (≥ ~$700k path)

| Market | Collateral needed | Idle now | PA / realloc | Can hot use now? |
|--|--|--|--|--|
| WETH/USDC `0x8793…1bda` | **WETH** | **~$7.6M** | Steakhouse/Prime/Yearn/Grove — large | **NO** — hot WETH = 0 |
| cbETH/USDC `0xdba3…cd0c` | **cbETH** | ~$81k | Yearn OG PA ~$1.1M | **NO** — hot cbETH = 0 |
| cbXRP/USDC `0xfdfe…9783` | **cbXRP** | ~$115k | Steakhouse HY **$1.0M** maxIn path | **NO** — hot cbXRP = 0 |

ELE/RSS markets (kingdom): PA shared **[]**, idle **$0**.

## Hot inventory outside ELE engine

| Asset | Amount |
|--|--|
| USDC | ~$60.75 |
| ELE/RSS | ~59.75 free (+ Morpho coll locked) |
| cbBTC | dust (~$1) |
| WETH / cbETH / cbXRP / BRETT wallet | **0** |
| BRETT Morpho dust | ~$1 supply |

## Actions (external → $700k USDC on hot)

1. **Acquire WETH ≥ ~$850k notional** (OTC/desk/MM), post on WETH/USDC `0x8793…1bda`, PA `reallocateTo` + `borrow` **$700k USDC** → hot. Script: `FireExternalWethPaBorrow.s.sol`.
2. **Same with cbETH** on `0xdba3…cd0c` if desk delivers cbETH.
3. **Same with cbXRP** on `0xfdfe…9783` (Steakhouse $1M PA).
4. **ELE path stays refinance/MM** (`SEED-700K-PLAYS.md`) — not an outside Morpho PA door.

Outside Morpho: USDC is on **WETH/cbETH/cbXRP** rails. Not on ELE.
