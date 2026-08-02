# Disk fill — path LIVE (scribed)

**Date:** 2026-07-27  
**Domain:** Base `8453`  
**Destination:** Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`

## What we did

1. **yELE WETH `acceptCap`** — $50M enabled  
   Tx `0x873cc2e45b4b32db14e1a82eef1fe30be364317051983abcca72767bcbf5d6a8`

2. **`FireDiskFill700k`** — curator path live  
   - Extractor `0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58`  
   - Flow: USDC → yELE (WETH queue) → realloc WETH→ELE → Morpho borrow → **Landing**  
   - Path checks with `ASK_USDC=1` credited Landing repeatedly

## Landing (live)

| Metric | Value |
|--|--|
| Landing USDC | **≥2** raw (path-check fills) |
| Hot USDC residual | ~**$0.64** |

## Machine

```bash
KING_GO=1 FIRE_DISK_FILL=1 ASK_USDC=<raw> \
forge script script/FireDiskFill700k.s.sol:FireDiskFill700k \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Full **$700k** ask = `ASK_USDC=700000000000` when hot holds ≥ that balance.

## Not in this scribe

`FireFlashSeedWETH` was never in-repo — flash magnet ≠ Landing payroll. DiskFill settles to Landing from USDC on hot / vault idle after deposit.
