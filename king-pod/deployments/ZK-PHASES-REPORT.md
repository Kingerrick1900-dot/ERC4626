# ZK Phases 1–9 — Status Report

| Phase | Action | Status |
|-------|--------|--------|
| 1 | Deploy verifier + gate + credit | **COMPLETE** |
| 2 | Generate proof ≥ \$700K | **COMPLETE** |
| 3 | Submit proof to gate | **COMPLETE** |
| 4 | `isProven = true` | **COMPLETE** |
| 5 | `EXECUTE_BORROW` via credit | **BLOCKED** — `NO_CREDIT_LIQUIDITY` |
| 6 | Confirm \$700K on hot | **NOT RUN** (blocked by 5) |
| 7 | Transfer hot → cold | **NOT RUN** (blocked by 5) |
| 8 | Confirm cold receipt | **NOT RUN** (blocked by 5) |
| 9 | Report to King | **THIS DOC** |

## On-chain facts (phase 5 attempt)

| Check | Value |
|-------|-------|
| Gate | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| Credit | `0xeAE626b6e82E51c9805D72B6532A948dcf57D392` |
| `isProven(hot)` | **true** |
| Credit USDC balance | **0** |
| `maxBorrow(hot)` | **0** |
| Hot USDC | **\$7.04** |
| Cold (Landing) USDC | **0** |
| Borrow want | \$700,000 |

Script armed: `FireZkBorrowToCold.s.sol`  
`KING_OK=1 FIRE_ZK_BORROW=1` — runs 5→8 when credit has USDC.

## What unlocks phase 5

Proof already authorizes the draw. **USDC must enter `CrownZkCredit`** (counterparty `supply`), then re-FIRE borrow → cold.

Or OTC: counterparty wires Landing after verifying `isProven` (path A in `ZK-PROOF-HOW-TO-USE.md`).
