# Scroll kXAU + eUSD sale-source pools — LIVE

Scroll dust pools were stood up with real inventory and real USDC so **kXAU** and **eUSD** have same-chain sale surfaces today. Desk plumbing — not kingdom law. No Morpho on Scroll.

## Live pools

| Pair | Fee | Pool | Seed |
|--|--|--|--|
| kXAU / USDC | 0.3% | `0xce5Dd7bF3acd10152a601563AE2730b3E4dCD241` | `0.02 kXAU` + `$0.20 USDC` |
| eUSD / USDC | 0.3% | `0x5f3f22344FbBF23DD6cF63670B05d4C6689063Fc` | `0.2 eUSD` + `$0.20 USDC` |
| kXAU / eUSD | 0.3% | `0x9c5768f292A85080294C7764b54930F3C560788d` | `0.05 kXAU` + `~0.5 eUSD` |

## Position NFTs

| Pair | Token ID | Owner |
|--|--|--|
| kXAU / USDC | `11056` | Scroll hot `0xca76AE9e29a5F01465D890dc30109cD58B78F864` |
| eUSD / USDC | `11057` | Scroll hot `0xca76AE9e29a5F01465D890dc30109cD58B78F864` |
| kXAU / eUSD | `11058` | Scroll hot `0xca76AE9e29a5F01465D890dc30109cD58B78F864` |

## Infra

| Item | Address |
|--|--|
| Uniswap V3 Factory | `0x70C62C8b8e801124A4Aa81ce07b637A3e83cb919` |
| NonfungiblePositionManager | `0xB39002E4033b162fAc607fc3471E205FA2aE5967` |
| USDC | `0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4` |
| kXAU (8dp) | `0x156d912F37C179798D8396Da5d58919FA634262d` |
| eUSD (18dp) | `0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B` |

## Tx hashes

| Action | Tx |
|--|--|
| Approve kXAU → NPM | `0x65732bb9dfffe0ed96c48095f5004c1d9daf97ce45b037e0bb2d430661219cb2` |
| Approve eUSD → NPM | `0x158c7d22331dd764653ddd042f121a5e9cf61cd84b1652e2b74ed0104ce22fb1` |
| Approve USDC → NPM | `0x54379d2e03581ba7474bdede71538e8be2a88657f9b19108c5b36ffa9460036a` |
| Create + init kXAU / USDC | `0x20b6049885bed123290dd461d35dbbbd613fced7a5944461588205dcf2187ab2` |
| Mint kXAU / USDC (`11056`) | `0x76e439514e8d711e83d47af64b08651d265a40f99d68fad8abee684e4fe432a5` |
| Create + init eUSD / USDC | `0xf9b7ef102067cdfd3cbbea4edf43cd237b0470104b1e76c9b01dd606a466462c` |
| Mint eUSD / USDC (`11057`) | `0x90a76f84bbf5b542b8337c85acdd6ba438e3e0c13903f543b9cfde34b55bf2b0` |
| Create + init kXAU / eUSD | `0xe400373de71c25a4ee59428c73e48b365b7d6ffb3751514db772ef9d593a89bd` |
| Mint kXAU / eUSD (`11058`) | `0x8037146b25089ef452de58a7238f61dc00b6cb10e8ed9ad1385635690eb2fffe` |

## On-chain balances (pool)

| Pool | token0 | bal0 | token1 | bal1 | liquidity |
|--|--|--|--|--|--|
| kXAU/USDC | USDC | `200000` ($0.20) | kXAU | `1999999` (~0.02) | `632455` |
| eUSD/USDC | USDC | `200000` ($0.20) | eUSD | `2e17` (0.2) | `2e11` |
| kXAU/eUSD | kXAU | `5000000` (0.05) | eUSD | `~5e17` (~0.5) | `~1.58e12` |

Full-range ticks (`±887220`). Factory `getPool` returns each address above at fee `3000`.

## Sale path check

LI.FI quotes succeed for tiny:
- kXAU → USDC
- eUSD → USDC

Aggregators route against these pools. Depth is **dust** — deepen when King sizes idle **R**.

## Notes

- All three pools were created live (`createAndInitializePoolIfNecessary` ~4.6M gas each).
- Funding: mint dust kXAU/eUSD on Hot + bridge ~$0.50 USDC Base→Scroll. Gold CDP **100,001 kXAU** untouched.
- Credit completer pool separately holds ~**$0.95** USDC (`0x5c251…`).
- Mirror of Base ELE/GOLD sales sources (`ELE-GOLD-SALES-SOURCE-LIVE.md`).
