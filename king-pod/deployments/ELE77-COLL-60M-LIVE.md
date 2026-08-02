# ELE77 collateral-only +35M — LIVE

**Directive:** Deposit +35M ELE collateral-only → 60M total. No debt draw. No seed.  
**Fired:** 2026-07-28 · Base hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`

## Results

| Field | Before | After |
|--|--|--|
| ELE77 coll | 25,000,000 ELE | **60,000,000 ELE** |
| Borrow (market) | $17,500,000 | **$17,500,000** (unchanged) |
| Borrow shares | 1.75e19 | **1.75e19** (unchanged) |
| Market supply | $17,500,000.000003 | **unchanged** (no seed) |
| Max borrow @ 77% / $1 | $19,250,000 | **$46,200,000** |
| Headroom | ~$1,750,000 | **$28,700,000** |
| Capacity util (debt/max) | ~90.9% | **~37.9%** |
| Free ELE on hot | ~74.0M | **~39.0M** |

## Tx

| Item | Value |
|--|--|
| Script | `script/FireEle77CollOnly.s.sol` |
| Guardrails | `DEBT_CHANGED` / `MARKET_SUPPLY_CHANGED` / `TARGET_60M` |
| Status | `ELE77_COLL_ONLY_OK` |

Broadcast: `king-pod/broadcast/FireEle77CollOnly.s.sol/8453/run-latest.json`

## Phase note

Headroom phase complete. Capacity ready for later draw when idle/PA available. No borrow executed this step.
