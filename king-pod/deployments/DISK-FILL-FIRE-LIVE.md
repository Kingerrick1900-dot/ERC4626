# FireDiskFill — LIVE (ASK_USDC=1 path check)

**Date:** 2026-07-27  
**Command:** `KING_GO=1 FIRE_DISK_FILL=1 ASK_USDC=1 forge script script/FireDiskFill700k … --broadcast`

## Result

| Field | Value |
|--|--|
| Landing Δ USDC | **1** (raw) |
| Extractor | `0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58` |
| Path | deposit yELE → realloc WETH→ELE → Morpho borrow → **Landing** |
| Status | `DISK_FILL_700K_OK` |

WETH `acceptCap` already live ($50M). Hot held ~$0.64 USDC; King fired ask=`1` as path check.

## Fixes applied for live fire

1. Realloc WETH target **0** (1-wei stub rounds to 0 on deep WETH book and bricks `transferFrom`)
2. Auto-supply ELE Morpho collateral before borrow (hot position was 0 after sovereign clear)
3. Borrow buffer skips $1 floor when idle is dust-scale

## Full $700k

Needs `ASK_USDC=700000000000` **and** ≥$700k USDC on hot. Same script.
