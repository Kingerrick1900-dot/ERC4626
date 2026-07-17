# Industry norm (not a new wheel)

## What the industry actually does
Morpho, Contango, Instadapp, DeFi Saver, Summer.fi all speed leverage the **same** way:

1. Post **your** margin / inventory
2. **One Morpho flash loan** collapses what used to be many borrow→supply loops
3. Supply + borrow + repay flash **in one tx**
4. End state = target size; flash is always repaid same block

Morpho docs call this out: flash loans replace iterative on-chain looping for target leverage. Contango: Morpho claims ~**64%** of volume is looping. YieldLooping notes: **do not add literal iteration** — flash reaches the same end-state in one shot.

## What that is NOT
Industry looping does **not** mint free USDC from a $2 dust cycle. It concentrates **existing** capital into full size faster and cheaper (gas + slippage).

## What we already shipped (matches the norm)
| Industry step | Our live piece |
|---|---|
| Free Morpho flash | Morpho Blue singleton float (~$190M USDC on Base) |
| One-tx leverage / rail | `CrownEliteFlashClose` `0x2192…D25` |
| Desk inventory = margin | `KingSeedDesk` |
| Vault receive | Cake `0xA1aF…832a` |
| Open self-lend (Peapods-style) | `CrownFlashOpen` (already proven) |

**Speed lever = industry lever:** load desk once → one flash-elite fire at full `$B`. Not invent a recursive printer.

## Scale to $700k the Contango way
Seat / inventory loads desk `$700k` → one `eliteFlashClose` → Cake `$700k`. Same pattern as one-click multiply; size is the margin, flash is the accelerator.
