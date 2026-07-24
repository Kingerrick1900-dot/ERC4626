# STOP — Recycle Loop Abuse

**Same mistake, repeated:** borrow USDC against Kingdom collateral → deposit own vault → same dollars re-supply Morpho → debt stays, ops cash ~$0.

That loop is **forbidden**.

## Hard rule

Borrow receiver = **Landing**. USDC **stays**.  
Never: Morpho borrow → yELE / yRSS / any Kingdom vault deposit in the same plan.

## Frozen

- `FireSelfSeedNine` — reverts `FROZEN: NO-RECYCLE-UNTIL-EXIT`
- Any “self-seed / scale / comfort throne” that recycles borrow into own supply

## Only allowed Morpho draw

`FireMorphoOpsDraw` — collateral → borrow → Landing KEEP → prove Landing USDC rose.
