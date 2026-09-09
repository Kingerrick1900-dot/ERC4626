# KING RAIL — engineered obedience

**Status:** LIVE DEPLOY / FIRE  
**Doctrine:** Smart contracts rule the terrain. Code obeys the king.

## CrownKingRail

Single rail for ALL-5:

| Fn | Step | Needs |
|--|--|--|
| `p1LandingWithdrawEusd` | L0 pull | **Landing key** |
| `p2PipeEusdToLanding` | HOT eUSD → Landing | HOT eUSD |
| `p3PayrollWithCbbtc` | Flash L6 payroll | cbBTC coll + `yrss.approve` |
| `p4AsymIdle` | Lasting USDC idle | cbBTC coll |
| OceanSeeder | P5 depth | already live |

P3/P4 repay flash from **cbBTC/USDC book** — never park borrow (no gasPark).

## Fire

```bash
KING_GO=1 OCEAN_TO_5B=1 P2_AMT=2000000000000000000000000 \
  forge script script/FireKingRail.s.sol:FireKingRailDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Addresses (filled after fire)

See broadcast + this file update post-deploy.
