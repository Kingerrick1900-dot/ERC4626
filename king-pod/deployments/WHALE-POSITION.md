# WHALE POSITION — engineer it (not “armed, wait”)

**King:** sitting duck · no whale position yet.  
**Chief:** agreed. Armed-wait is a sink. Below is the **whale book** — designed under `LIVE-FIRE-LAW` (**no live fire until King OK**).

---

## Sitting duck (today)

| Leg | Now | Why duck |
|-----|-----|----------|
| Free RSS | ~16.8M on hot | Unstructured inventory |
| Posted coll | ~1.0M | Pilot credit line, not whale size |
| USDC face on Blue | ~$0 idle | Cannot draw |
| yRSS TVL | ~$299 | No supply whale |
| PA caps | ~$700k | Retail pipe, not whale pipe |
| Desk | 700k listed | Block tool without a whale buyer |
| Capture/wait | — | **Slow sink** |

Morpho priced you at **~$14.2M LLTV**. A whale **uses** that. A duck **announces** it and sits.

---

## What a Steakhouse-class whale position IS

Not “collateral posted.” A **closed system** with both sides:

```text
SUPPLY WHALE          PIPE              DEMAND WHALE
(USDC in yRSS)   →   PA / alloc    →   (RSS coll + borrow)
     ↑                                      ↓
  fee 10% King                         Landing / ops
     ↑                                      ↓
  APY magnet  ←── interest paid ────────────┘
```

Plus **block exit** (desk) so inventory clears without Morpho.

---

## THE WHALE POSITION (Kingdom target book)

| Leg | Target | Role |
|-----|--------|------|
| **D1 — Demand coll** | **10M–18M RSS** posted on RSS Blue | Whale borrow capacity (~$7M–$14M @ 70–77%) |
| **S1 — Supply vault** | **yRSS TVL ≥ $5M** (Phase wedge **$500k–$1M**) | USDC face — lenders who get paid |
| **P1 — Pipe** | PA maxIn/Out **$5M** (raise from $700k) | Whale-sized JIT |
| **E1 — Block exit** | Desk facility **$1M–$5M** tranches | Place RSS for USDC without Morpho idle |
| **T1 — Treasury** | Landing **≥ $500k** buffer | Stop being prey |
| **G1 — Gov shell** | guardian + timelock (after cash) | Institutional posture |

**Phase 1 wedge inside the whale:** Landing **$500k** (desk or first $500k idle draw).  
That is the first scale step of the whale book — not the whole whale.

---

## How we STOP being a sitting duck (engineered paths)

### Path W1 — First Whale Seed (supply-side, no Gauntlet beg)

**Design:** On-chain facility (code ready, **deploy only on King OK**):

1. Kingdom locks **RSS rebate budget** (e.g. 50k–200k RSS) into `CrownFirstWhale`.  
2. First depositor(s) who push **≥ $500k USDC into yRSS** (or supply RSS Blue) unlock rebate.  
3. That USDC becomes idle → Kingdom borrows to Landing (pay bills).  
4. Whale gets: **supply APY + RSS rebate**; Kingdom gets: **cash + util magnet**.

This is **engineering a whale to sit on OUR book** — incentive, not petition.

### Path W2 — Demand whale (size the coll)

On King OK only: scale posted RSS from ~1M → **10M+** so when USDC arrives, draw is whale-sized — not a $700k toy line.

### Path W3 — Block whale (desk)

Restock desk to **$1M–$5M** tranches; helper already exists. One whale OTC fill = Phase 1 done without Morpho idle.

### Path W4 — Cap raise

On King OK: PA + yRSS caps **$700k → $5M** so the pipe matches the coll.

---

## Code shelf (built / building — NO broadcast)

| Artifact | Purpose |
|----------|---------|
| `src/CrownFirstWhale.sol` | Rebate facility for first ≥$500k USDC face |
| `script/FireWhalePosition.s.sol` | Dry-run scoreboard + staged OK fires |
| `YIELD-DEMAND-SIGNAL.md` | Demand-side pitch (LP yield) |
| `CHIEF-3-PHASE-EXPAND.md` | Phase map |
| Desk + helper | Already live (prior OK era) — no further live touches |

---

## Scoreboard: duck → whale

| Metric | Duck | Whale |
|--------|------|-------|
| Landing | ~$2 | **≥ $500k** then growing |
| yRSS TVL | ~$299 | **≥ $5M** |
| RSS posted | ~1M | **≥ 10M** |
| PA pipe | ~$700k | **≥ $5M** |
| Idle / desk raised | $0 | **≥ $500k** captured |

---

## Chief law

- **Whale position = both sides of the book + pipe + exit + treasury.**  
- Collateral alone = sitting duck.  
- Wait loops = slow sink.  
- **No live deploys until King OK** (`LIVE-FIRE-LAW.md`).  

**Next when King says OK:** deploy `CrownFirstWhale` · raise caps · scale coll · restock desk — in that order he chooses.
