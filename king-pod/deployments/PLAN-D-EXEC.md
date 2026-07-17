# Plan D — Borrow-and-hold (real USDC, debt kept)

## What it is
Post RSS on Morpho → borrow hard USDC → send to vault → **leave the Morpho debt open** (healthy HF). Vault gets cash. No RSS buyer. No liquidation bot. No paper sUSDC.

## Gate
Morpho market must have **external USDC lenders**. Right now liquidity ≈ 0. Without lenders there is nothing to borrow.

## Execution (when float exists)
1. Keep oracle/LLTV as set (77% @ $0.05).
2. Borrow max safe against free RSS → vault `0xA1aF…832a`.
3. Monitor HF; top up coll or partially repay only to avoid liquidation.
4. Unwind later only when King chooses (needs USDC to repay).

## If King rejects every external party
There is no remaining on-chain plan that increases vault USDC. Every hard dollar comes from a counterparty (lender, buyer, or liquidation victim). Dust loops and paper LP do not.

## Kill list
- Plan A buyers
- Plan B V1 paper
- Plan C liq bot (rejected)
- Elite-close dust spins
