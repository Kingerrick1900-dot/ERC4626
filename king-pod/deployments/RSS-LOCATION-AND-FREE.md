# RSS location map + free status (Base)

> **SUPERSEDED for liquid bag location.**  
> Primary: `RSS-NOT-CRASH-LOCATED.md` (2026-10-01) + **`RSS-RECON-LEDGER.md`** (2026-11-23 handoff).  
> Live: HOT wallet RSS = **0**; **~9,497,295 RSS** Morpho coll on `0x6075ba26…` (eUSD loan); **~100k** on `0x5dd0f7c1…`; **700k** sale inventory `0xdbf7…`.  
> Yearn/`CrownRwaLoop` fire: **STAND DOWN** (`STAND-DOWN-YRSS-LOOP.md`).

Live read confirms **all 21,000,000,000 RSS** is accounted for. Nothing is missing.

## Where the tokens are (historical table — do not use for ops)

| Amount | Location | Status |
|--------|----------|--------|
| **20,981,500,000 RSS** | KingPair V1 `0x56ebfc0af28e1a9d8e6f9d0f3262ff1ad1a78f8c` | **Stuck** — LP held by Market V1; V1 has **no** `releaseCollateral` |
| ~~**18,500,000 RSS** Morpho freeable~~ | superseded | See recon ledger — not “free on hot” |
| **0 RSS** | King hot wallet | confirmed live |

## Why hot does not hold the liquid slice

Freed RSS was re-posted via `postCollateral` helpers into Morpho eUSD/RSS markets (Aug 2026 trail). See `RSS-NOT-CRASH-LOCATED.md`.

## Free path A — Morpho kingdom bag (current)

Repay eUSD debt on `0x6075ba26…` (+ `0x5dd0f7c1…` if open), then `withdrawCollateral` → Landing. HOT wallet holds **~3B eUSD** (enough for ~1.18B debt on main book).  
**Hard rule after free:** do **not** recycle (`NO-RECYCLE-UNTIL-EXIT.md`).

## Free path B — V1 pair 20.9815B

**Not freeable with current V1 bytecode.** Market holds the LP; no exit/release. Paying the $170k debt mapping does not unlock LP without `releaseCollateral`. V2 does not migrate V1 LP.
