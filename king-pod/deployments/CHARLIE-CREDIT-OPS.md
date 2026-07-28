# Charlie — Credit Ops evaluation (ELE77)

**Date:** 2026-07-28 · Base hot `0x6708…a7d1`  
**Ask reference:** $500,000 Landing USDC

## Position

| Field | Live |
|--|--|
| Collateral | **25,000,000 ELE** |
| Soft coll USD @ $1 | **$25,000,000** |
| LLTV | **77%** → max **$19,250,000** |
| Current borrow | **~$17,500,000** |
| Headroom | **~$1,750,000** (≥ $500k) |
| Market idle | **~$0** |
| Hot WETH/cbBTC Morpho coll | **0** |

## Prudence checklist

| Check | Pass? |
|--|--|
| Available borrowing headroom ≥ ask | **YES** (~$1.75M) |
| Borrow rates sustainable | Matched util ~100% — rate elevated; ok for short ops if idle appears |
| Collateral ratio after +$500k | Still under 77% (would use ~$18M / $25M ≈ 72%) |
| Liquidity availability (idle / PA) | **NO** — idle≈0; foreign maxIn=0 |
| Treasury repayment plan | Requires Landing ops revenue or later idle refill — **not armed** |

## Decision

**Do not borrow.** Headroom without idle is not executable. Expanding ELE leverage while the book is matched does not put USDC on Landing.

**Re-open when:** ELE77 idle ≥ ask **or** foreign PA maxIn ≥ ask with reallocatable WETH/cbBTC idle — then `RAIL_MODE=BORROW_IDLE`.

ELE remains sovereign collateral (Bravo). Liquidity stays on WETH/cbBTC rails (Alpha).
