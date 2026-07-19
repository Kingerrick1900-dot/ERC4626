# NO RECYCLE UNTIL EXIT — King order

**Effective immediately after any Morpho free.**

## Rule

Anything freed (RSS on hot, leftover USDC, yRSS residual) must **sit liquid**.

**Do not** put it back into:

- Morpho `supplyCollateral` / borrow / self-lend / self-seed
- yRSS deposit as a recycle leg
- King Pod / KingPair / Market V1 or V2 lock
- Any new “PoD / TVL / loop” that has no tested unwind

…until there is a **fork-tested exit** that returns the same assets to hot in one proven path.

## Allowed now

1. Run `DeployAndChunkFreeRss` → ~18.5M RSS to hot (dust ~$300 debt + ~400 RSS may remain).
2. Leave RSS on hot. Gas only.
3. V1 **20.98B** stays stranded — do not add more to it.

## Forbidden scripts until King lifts freeze

- `FireSelfSeedNine.s.sol`
- `FirePositionSeed700k.s.sol`
- `CrownSelfSeedNine`
- Any carry/scaler that re-locks King RSS

## Exit bar (minimum)

Before any re-lock: a forge fork test that opens the position **and** fully unwinds back to hot with **zero** stranded LP / debt / shares — run twice. No story charts.
