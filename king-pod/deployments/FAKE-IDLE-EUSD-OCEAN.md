# FAKE IDLE LIVE — Morpho-visible eUSD idle (no Circle USDC)

**Status:** FIRING  
**Crack:** Protocol-stable unmatched Morpho supply = visible idle without Circle USDC. Same class of move as mint–mint pools.

## Contracts

| | |
|--|--|
| `CrownFakeIdleEusd` | Morpho supply eUSD only · never borrow |
| `CrownOceanSeeder` | mint eUSD → wrap gUSD → Aero LP both sides |
| Target market | `0x6075ba26…867b` RSS/eUSD |

## Fire

```bash
# Deploy + engineer $2M eUSD idle from HOT free balance
KING_GO=1 FAKE_IDLE_AMT=2000000000000000000000000 \
  forge script script/FireFakeIdleOcean.s.sol:FireFakeIdleDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# Ocean (mint-mint) — set OCEAN=1 SIDE=1e24 (1M/side) or larger
KING_GO=1 OCEAN=1 OCEAN_SIDE=1000000000000000000000000 \
  forge script script/FireFakeIdleOcean.s.sol:FireFakeIdleDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```
