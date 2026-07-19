# NO RECYCLE UNTIL EXIT — King order

**Effective immediately after any Morpho free.**

## Rule

Anything freed (RSS on hot, leftover USDC, yRSS residual) must **sit liquid**.

Landing wallet (preferred liquid destination): `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`

**Do not** put it back into:

- Morpho `supplyCollateral` / borrow / self-lend / self-seed
- yRSS deposit as a recycle leg
- King Pod / KingPair / Market V1 or V2 lock
- Any new “PoD / TVL / loop” that has no tested unwind

…until there is a **fork-tested exit** that returns the same assets to hot/landing in one proven path **and King green-lights live use**.

## Allowed now

1. Leave freed RSS liquid on hot or land on landing wallet. Gas only.
2. V1 **20.98B** stays stranded — do not add more to it.
3. Fork-work / simulate Vault V2 deploy — **no live broadcast** until King says.

## Forbidden scripts until King lifts freeze

- `FireSelfSeedNine.s.sol`
- `FirePositionSeed700k.s.sol`
- `CrownSelfSeedNine`
- Any carry/scaler that re-locks King RSS
- `DeployKingVaultV2.s.sol` **broadcast** (requires King `LIVE_ARMED=1`)

## Exit bar (minimum)

**Vault V2 access (fork):** PASS — see `VAULT-V2-FORK-PASS.md` (`forceDeallocate` ×2 at ~100% util).

Before any re-lock: live V2 must be deployed **only after King green light**, then a live-proven unwind back to landing. No story charts.
