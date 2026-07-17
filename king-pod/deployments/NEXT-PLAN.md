# NEXT PLAN — not Morpho seed → borrow again

## Dead loop (do not repeat)
Seed King’s RSS/USDC Morpho market → borrow against RSS → vault.  
Same idea every coat. Market supply is dust. **Scrapped as the plan.**

## Different machine (already deployed)
Morpho’s big USDC pile is **flash float** — use it inside one transaction, repay same tx, keep the leftover.

King already has:
- `CrownFlashRouter` `0x1373…2577` — Morpho 0% in → charges fee out → fee to King
- `CrownFlashArb` `0xD17D…366d` — flash USDC → buy/sell mispriced route → profit to treasury → repay flash

No RSS Morpho seed. No borrow-and-hold. No “fill the loan pile first.”

## The plan
1. **Hunt** Base USDC routes where buy-low / sell-high leaves profit after router fee + gas.
2. **Fire** `CrownFlashArb.flashArbitrage` only when `minProfit` clears.
3. **Land** profit USDC on King treasury / vault.
4. **Optional second rail** — other bots flash through `CrownFlashRouter` and King earns the fee (5 bps live) with zero RSS involved.

## Why this is not the old loop
| Old loop | This |
|----------|------|
| Needs permanent USDC sitting in King’s Morpho RSS market | Uses global Morpho flash, repaid same tx |
| Win = debt against RSS | Win = leftover USDC after repay |
| Blocked at supply ≈ 0 | Blocked only when no profitable route |

## Honesty
- No arb edge → no profit that day. Machine does not invent USDC from empty air.
- Not a liquidation bot (King already killed that).
- Not public Morpho depositors into King’s RSS market.
- No broadcast without King greenlight.

## First build step (when greenlit)
Scanner: quote candidate 2-leg USDC routes on Base → if profit > fee + gas + cushion → return calldata for `flashArbitrage`. Parked until King says go.
