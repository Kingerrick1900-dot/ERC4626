# KESOV Rescue Desk — Phase 2

Live deployment on VPS `5.78.226.227` at `/opt/kesov-kingdom/`.

## Product

Whale rescue desk: enroll at-risk borrowers, exclude them from liquidation queue, monitor HF, accrue 7% performance fee on successful rescues.

## Components

| Piece | Path |
|---|---|
| DB tables | `rescue_clients`, `rescue_events` in `kingdom.db` |
| Schema + helpers | `src/db.ts` — `isRescueClient`, `enrollRescueClient`, `purgeRescueFromQueue` |
| Queue exclusion | `intelligence.ts`, `upsertLiquidationQueue`, `claimNextTarget` |
| HF monitor | `src/rescue-monitor.ts` — 30s loop, deduped alerts |
| API + UI | `src/intel.ts` — `/api/rescue`, `/api/rescue/enroll`, Rescue tab |

## Env

```
RESCUE_FEE_PCT=0.07
RESCUE_MONITOR_INTERVAL_MS=30000
RESCUE_ALERT_HF_WARN=1.05
RESCUE_ALERT_HF_CRITICAL=1.02
RESCUE_ALERT_DEDUPE_SEC=3600
```

## Deploy

```bash
python3 scripts/phase2-rescue-deploy.py
```

## Verified (2026-07-13)

- `[rescue] monitor live | interval=30000ms fee=7.0%` in kesov-kingdom logs
- `GET /api/rescue` returns enrolled clients with live HF
- Test whale `0x5a820bd80a297454c0edd28fc3a3e959c6f2f4fa` (cbBTC/USDC HF≈1.0004) enrolled
- `hf_critical` alert fired within 30s
