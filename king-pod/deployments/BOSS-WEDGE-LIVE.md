# CrownBossWedge — LIVE (USDC engineered from eUSD)

| Field | Value |
|--|--|
| **CrownBossWedge** | `0x9f986DbAd3f3Ca3a56Aa4fef8877A2417ca12629` |
| Borrowed vs eUSD | **$0.800054** (all Boss idle) |
| Peeled → Landing | **$0.800054** |
| Landing USDC after | **~$2.51** |
| Boss idle left | **~$0** (drained) |

## Audit vs P1.5 claim

| Claim | Result |
|--|--|
| Borrow **$1.01M** from Boss with eUSD coll | **Impossible today** — book only had ~$0.80 |
| Engineer USDC from HOT eUSD | **DONE** — drained the book |
| Vacuum | Re-call `drainWedge(0)` when Boss idle refills (queue sends new USDC there first) |

## Depth-First

Keep ocean ~5B — attracts loan-side fill → vacuum scales. Depth ≠ payroll; vacuum converts fill to peel.
