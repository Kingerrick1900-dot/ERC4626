# ZERO DEBT — kUSD engine unwound

**Doctrine:** King/Kingdom carries **no debt** until the Kingdom has earned.

## LIVE (2026-07-22)

| Check | After |
|--|--|
| kUSD engine `debtOf(hot)` | **0** |
| kUSD engine `totalDebt` | **0** |
| kUSD engine RSS coll | **0** (was 1M) |
| Morpho RSS/USDC debt/coll | **0 / 0** |
| Hot RSS | **~15.03M** (14.03M + 1M returned) |
| Hot kUSD | **0** (burned in repay) |

## Path

1. Dust gap: hot had 699,994 kUSD vs 700,000 debt → minted **$6** kUSD (owner setMinter briefly)  
2. `setMinter` restored to engine `0x9f93…5768` (repay needs engine as minter to burn)  
3. `repay(700000e6)` — tx `0x42ff9948…6c996c`  
4. `withdraw(1M RSS)` — tx `0x51da7ecc…ad9b73`

## Not debt (still stranded elsewhere)

- KingPair V1 ~20.98B RSS (ghost face, $0 USDC backing) — not Morpho/kUSD debt  
- RSS token **cannot mint** (no mint on bytecode) — cannot print to 25M without recovering bags  

## Rule going forward

No Morpho borrow / no kUSD engine debt / no self-seed debt until Kingdom has **real external earn**. Zero debt is the seat.
