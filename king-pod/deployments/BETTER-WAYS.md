# Better ways (loan/sale plan removed)

## Scrapped
- RSS sale / private seat as the plan
- Personal loan wire as the plan
- Empty-market Morpho borrow
- V1 “$170k cash” (debt is $170k on books; sUSDC `totalAssets=0`; USDC already pulled; deployed V1 has **no** `releaseCollateral`)
- Dust elite-close recycle as new money

## What’s actually on the board
| Item | Reality |
|------|---------|
| Vault | ~$4.87 hard USDC (recycle from King rails — not new) |
| Morpho RSS market | ~$0 supply — cannot borrow |
| V1 LP | Locked on market; King debt $170k; no exit fn on deployed code |
| Global Morpho $190M | Flash float only — must repay same tx |

## Better ways (not sale/loan pitch)
1. **Market activation** — get USDC *suppliers* into King’s Morpho market (yield depositors / curator allocation). Then borrow-and-hold to vault. Different from selling RSS.
2. **V1 surgery research** — only if a new exit vector appears (none on current bytecode). Don’t budget hope.
3. **Machine stays parked** — eliteFlashClose `railBps=0` ready when hard USDC exists. No autonomous fires without greenlight.

No txs without King greenlight.
