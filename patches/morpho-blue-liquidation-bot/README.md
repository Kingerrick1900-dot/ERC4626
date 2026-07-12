# Morpho Blue Liquidation Bot — Scribe Placeholder Fix

Apply this patch to `Kingerrick1900-dot/morpho-blue-liquidation-bot` on branch `cursor/fix-scribe-placeholders-0638`.

## Problem

The Armed Queue was surfacing `profit: 9999999.0` and `debt: 0.0` while a row sat in `executing` — placeholder telemetry leaking before simulation completed.

## Fix

- `apps/client/src/telemetry/Scribe.ts` — real Armed Queue lifecycle (`armed` → `simulating` → `executing` / `sim_failed`)
- `apps/client/src/telemetry/sentinels.ts` — rejects sentinel profits (`9999999`, etc.)
- `apps/client/src/bot.ts` — wires Scribe into liquidation; profit/debt only after `simulateCalls`
- `apps/client/test/vitest/telemetry/scribe.test.ts` — regression tests

## Apply

```bash
cd morpho-blue-liquidation-bot
git checkout -b cursor/fix-scribe-placeholders-0638
cp -r /path/to/patches/morpho-blue-liquidation-bot/apps/client/* apps/client/
pnpm exec vitest run apps/client/test/vitest/telemetry/scribe.test.ts
git add apps/client && git commit -m "fix: eliminate Scribe placeholder profit/debt leak in Armed Queue"
```

## Verify

After deploy, Armed Queue rows should show:

- `profit=—` during `armed` / `simulating`
- Real USD profit only after simulation succeeds (`executing`)
- `simfail` log + `sim_failed` status on revert — never `executing` with `9999999`
