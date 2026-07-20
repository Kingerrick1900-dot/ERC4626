# NO RECYCLE UNTIL EXIT — King order (updated)

## Exit bar — MET

- Vault V2 live + `forceDeallocate` **live-proven** (gas-only). See `VAULT-V2-LIVE-EXIT-PROVEN.md`.
- Cold landing / hot daily roles set.

## Phase 1 — Restore self-seed fortress (AUTHORIZED)

King ordered fortress restore. Self-seed is **unfrozen** behind gates:

- `FireSelfSeedNine.s.sol` — needs `KING_GO=1`
  - `FIRE=0` → prep (deploy + auth + RSS-first queue)
  - `FIRE=1` → atomic self-seed ($9M default)

See `PHASE-1-RESTORE.md`.

## Kingdom debt free + ops (AUTHORIZED on King GO)

Pay Morpho loan / free RSS working asset:

- `FireKingdomDebtFree.s.sol` — needs `KING_GO=1`
  - `FIRE_FREE=0` → deploy freer + auth
  - `FIRE_FREE=1` → `CrownChunkFreeRss.freeRssToKing()` (+ optional Landing sweep)

See `PHASE-DEBT-OPS.md`. RSS may go lighter when debt is paid — that is the asset’s purpose.

## War elephant (Vault V2 path)

- `FireWarElephant.s.sol` — needs `KING_GO=1` + `FIRE_ATTACK=1`
- `FireFeedWarElephant.s.sol` — needs `KING_GO=1` + `FIRE_FEED=1`

See `WAR-ELEPHANT-PLAN.md`.

## Still forbidden without King go

- Ad-hoc Morpho re-lock / carry scalers
- Using exposed/old Cake wallet
- Borrowing against depositor capital
- Mixing FEED into unrelated txs

## Landing

`0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` — cold Cake (new). Never paste seed.
