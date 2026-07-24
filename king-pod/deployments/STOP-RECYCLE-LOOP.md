# STOP — Own-vault recycle only

**Morpho borrow is allowed.** King follows Morpho: collateral → borrow → keep cash on Landing.

**Forbidden:** borrow USDC → deposit Kingdom’s own vault (yELE/yRSS) → re-supply same market → debt with no bills money.

| Do | Don’t |
|--|--|
| `FireMorphoOpsDraw` / `FireDirectBorrow` → Landing KEEP | Self-seed / comfort-throne recycle |
| Open idle via Blue supply or whale markets | Call Morpho seeding “abuse” |

`CrownSelfSeedNine.selfSeed` stays frozen. Ops Morpho draws stay armed.
