# FAKE IDLE — LIVE

**Fired.** Morpho-visible idle without Circle USDC + mint–mint ocean depth.

## Live

| | |
|--|--|
| **CrownFakeIdleEusd** | `0xFCD6BB3284b8560c0ec733c2E3c6E9848100596E` |
| Market | `0x6075ba26…867b` RSS/eUSD |
| Engineered | **+$2,000,000 eUSD** unmatched supply |
| Idle before → after | **~$43.34M → ~$45.34M eUSD** |
| utilBps | **9592** |
| **CrownOceanSeeder** | `0x5AE22813c4560fA28a3C2e4c7e918Da42904c099` |
| Ocean seed | **1M eUSD + 1M gUSD** into Aero `0x8C009d…` (LP to Landing) |
| Pool after | eUSD/gUSD reserves **21M / 21M** (was 20M/20M) |

## What this is

Industry fake depth: protocol stable as Morpho loan-token idle + both-side mint LP.  
Not Circle USDC. Not gasPark. Borrow hard-blocked on FakeIdle.

## Scale

```bash
# More Morpho eUSD idle (mint path)
KING_GO=1 FIRE=1 FAKE=0xFCD6…596E AMT=… MINT=1 \
  forge script script/FireFakeIdleOcean.s.sol:FireFakeIdleMore --rpc-url $BASE_RPC_URL --broadcast --slow

# Bigger ocean
KING_GO=1 FIRE_OCEAN=1 OCEAN=0x5AE2…4099 SIDE=… \
  forge script script/FireFakeIdleOcean.s.sol:FireOceanSeed --rpc-url $BASE_RPC_URL --broadcast --slow
```
