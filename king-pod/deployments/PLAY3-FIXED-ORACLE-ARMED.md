# PLAY 3 — Fixed Oracle Advantage (armed, waiting King OK)

## Pick
Fixed Oracle Advantage. Not Flash NAV. Not recursive buy loops. Not incentive week.

## Why this one
King already owns MorphoFixedOracle. Price is live at one dollar per RSS. Market exists. Collateral is posted. About eighteen and a half million RSS sits on Morpho against roughly nine and a quarter million circular book. Health factor sits near one point five four. That leaves about five million dollars of borrow headroom on paper the moment any idle USDC is in the market. The oracle is the lever. The loan is the feed.

## What already happened on-chain (not waiting)
Oracle set to one dollar. Desk and sale prices matched. Proof of demand book opened and scaled. Public Allocator armed on yRSS with cbBTC, WETH, and RSS in queue. CrownSpoilFire deployed and Morpho-authorized to borrow to KingVault. Morpho authorization for spoil fire is live.

## What fires when King says OK
One path only: take idle USDC in the RSS market and borrow it to KingVault against the live RSS collateral at the fixed one dollar oracle. Debt stays. RSS stays posted. Vault keeps hard USDC. No elite-close. No selling the posted stack to zero the loan.

If idle is still zero at fire time, the same OK arms the cross-flash treasury path: flash USDC from Morpho global float, supply on a separate sink address, borrow the same size to KingVault, repay the flash from a repay rail that is not the vault borrow proceeds. That is loan plus token. That is Play 3 finished.

## What will not be touched without a separate OK
Flash NAV against other curators vaults. Withdrawal queue drain of depositors in foreign vaults. Deploy of new uncapped elite oracle markets. Broadcast of any new treasury fire.

## Paired play
Play 5 Self-Supply Boost is armed alongside this pack. Play 5 can place King USDC into the market as idle; Play 3 borrows that idle to KingVault and holds the debt.

## Status
Play chosen. Fire pack ready. No further deploy or broadcast until King OK.
