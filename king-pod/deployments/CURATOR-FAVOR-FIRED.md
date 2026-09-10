# FIRED — Curator favor pack (live Base)

**Status:** FIRED · success  
**Script:** `script/FireCuratorFavor.s.sol`

## What changed

| Action | Result |
|--|--|
| Enable USDC **idle** market `0x38c846…` | **on** · cap **$50M** |
| **Supply queue** order | **1 eUSD/USDC → 2 idle → 3 park → RSS40 → cbBTC → WETH → BRETT** |
| Park PA flow | **$2M / $2M** (was $700k) |
| cbBTC + WETH PA maxIn | **$2M** each (was **0**) |
| Idle PA flow | **$50M / $50M** |
| Landing `isAllocator` | **true** |

## Effect

New yRSS deposits route into **eUSD/USDC** first — the market where kingdom **eUSD** is borrow coll for Circle USDC. Idle market is the Morpho buffer slot. Park/cbBTC/WETH JIT doors widened.

## Next

When eUSD/USDC (`0x5d46…`) liquidity rises: fire `CrownEusdBorrowUsdc` (borrow USDC vs eUSD → park idle / peel).
