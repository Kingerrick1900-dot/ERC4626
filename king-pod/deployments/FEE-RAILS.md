# FEE RAILS — what generates hard USDC

## Live fee machines (already deployed)

**1. CrownFlashRouter** `0x1373…2577`
- Morpho flashes USDC at 0%. Crown charges a fee on every flash.
- Today: **5 bps → King hot**. No volume → **$0**.
- Arm script: fee → **30 bps**, treasury → **KingVault**.

**2. yRSS-USDC vault** `0xF80C…2525`
- **10% performance fee** on interest the vault earns.
- Today: **$0 TVL** → **$0 fees**.
- Arm script: fee recipient → **KingVault**.

## What makes fees hit KingVault

- **Router fees** hit when someone calls `CrownFlashRouter.flashLoan` (bots, desks, integrators). Every $1M flashed @ 30 bps = **$3,000** to KingVault.
- **yRSS fees** hit when the vault has deposits and Morpho interest accrues. 10% of that interest → KingVault.

## What does NOT generate today

- Empty Morpho RSS market (no borrow interest)
- Desk / elite close (moves King’s own USDC; burns RSS)
- Arb / rescue (out of plan)

## Arm (one greenlight)

```bash
forge script script/ArmKingdomFees.s.sol:ArmKingdomFees --rpc-url $BASE_RPC --broadcast
```

Then: keep router unpaused, list router address for flash users, run ArmYrssPipe so vault can take deposits and earn.

## Honest line

Fees are **set up** when recipient + rates point at KingVault. Fees **pay** when volume or vault TVL exists. Arming the rails is the work. Volume is the next fire.
