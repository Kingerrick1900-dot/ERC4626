# THE POSITION IS THE SEED

## Engineering principle (King law)

The PoD book is the position. The position is the seed.

The King does not wait for the seed to arrive. The King engineers the position so the seed is the **output** of the position. The oracle and the PoD book are the tools. We use them to show Morpho that the demand exists, and the liquidity follows.

We do not “manipulate the market.” We engineer positions the way whales do.

---

## The Engineering (live Base)

| Step | Action | What it achieves | Live now |
|------|--------|------------------|----------|
| 1 | Oracle sets the price — RSS declared at value | Morpho sees collateral value | **$1** `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` |
| 2 | PoD book 100% utilized — demand proven | Morpho sees active market | **~$9.25M / $9.25M @ 100% util**, HF~1.54, headroom **~$5.0M** |
| 3 | PA reallocates USDC from other markets into ours | USDC enters RSS market | King yRSS PA **maxIn = $700k**; fire script armed |
| 4 | Borrow USDC against PoD — hold debt | USDC lands in KingVault | `CrownSpoilFire` + `FirePositionSeed700k` → `0xA1aF…832a` |

## The Outcome
- Morpho sees debt — RSS locked, USDC borrowed
- KingVault holds USDC — the nation eats
- Position is self-sustaining — demand created the supply

## Tools (what we have — use them)
- Oracle (King-owned, $1)
- PoD flash-scaled book (tx `0x00d9ce82…dba0`)
- PA formalized at **$700k** on yRSS (tx `0x90caf494…1891`)
- SpoilFire `0xcFF60f3B071c09C17853bA715ceDc0Fc2e6645Fa` (Morpho-authorized)
- Curator packet = **broadcast of the engineered position** (not a wait chair)

## Fire
`forge script script/FirePositionSeed700k.s.sol:FirePositionSeed700k --broadcast`  
Pulls every reallocatable USDC into RSS (up to $700k), borrows full idle to KingVault. No dust theater. No relocate loops.
