# RSS secondary liquidity depth plan

## Gap
Curators require **verifiable on-chain liquidity depth** for collateral. As of 2026-07-18:

- UniV3 / UniV2 / Aerodrome CL: **no RSS/USDC or RSS/WETH pools**
- DexScreener / GeckoTerminal: **0 pairs**

Oracle objection is closed (FixedOracle owner → `dEaD`). Depth is the remaining unlock for larger caps / Prime consideration.

## Seed design (when USDC runway exists)
| Param | Choice |
|--|--|
| Venue | Uniswap V3 on Base (factory `0x33128a8fC17869897dcE68Ed026d694621f6FDfD`) |
| Pair | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` / USDC |
| Fee | **10000** (1%) — thin long-tail collateral |
| Initial size | Minimum useful: **$25k–$50k** USDC + matching RSS at $1 oracle peg |
| Range | Full-range first for curator optics; tighten later |
| Reporter | Pool address + `liquidity` + DexScreener link posted to forum threads |

## Funding order (no inventing USDC)
1. Curator `maxIn` → borrow → KingVault (Step 2) **or**
2. External yRSS deposits → allocate → borrow → KingVault **or**
3. Ops inventory (Step 3) — currently exhausted after loop sweep

**Do not** flash-seed the pool without a named repay source (`FLASH-POLICY.md`).

## Curator messaging
- HY / Core: ask **now** at $700k cap with depth plan disclosed  
- Prime: only after pool live + measurable depth  
