# FIRE — Kingdom Reserves Pull

**Mode:** FIRE · Base  
**Order:** HOT repay + 1.5B eUSD seat → Landing ocean 1.5B LP + Morpho gUSD → HOT

## Targets

| Leg | Source | Destination | Amount |
|--|--|--|--|
| eUSD reserve | Safe Morpho eUSD/RSS | HOT | **1.5B eUSD** |
| gUSD ocean | Aerodrome stable `0x8C009d96…eFE7` | HOT | **1.5B gUSD** (+1.5B eUSD pair leg) |
| King 30M | Morpho gUSD/RSS Landing supply (post-repay) | HOT | **~100M gUSD** (30M liquid unlocked) |

## Scripts

1. `script/FireKingdomReservesHot.s.sol` — `FIRE_KINGDOM_RESERVES_HOT=1` · `HOT_KEY` · `ZK_SHIELD=1`
2. `script/FireKingdomReservesLanding.s.sol` — `FIRE_KINGDOM_RESERVES_LANDING=1` · `LANDING_PRIVATE_KEY` · `ZK_SHIELD=1` · `KING_CUSTODY_OK=1`

## Fork proof

`test/SimKingdomReserves.t.sol` — repay ~70.168M gUSD · HOT eUSD ≥ 1.5B

## Live hashes

_Pending broadcast._
