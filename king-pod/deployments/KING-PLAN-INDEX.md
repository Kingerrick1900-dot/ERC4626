# KING PLAN INDEX — read before any live fire

**Law:** King reads the plan → then OK / GO / FIRE.  
No `--broadcast` until that order for **that** plan.  
See `LIVE-FIRE-LAW.md`.

---

## Active doctrine plans (read these)

| # | Plan | File | Live status |
|---|------|------|-------------|
| 1 | **Create opportunities** (solo King — no bring / no someone) | [`CREATE-OPPORTUNITIES.md`](./CREATE-OPPORTUNITIES.md) | **PLAN ONLY** |
| 2 | Live fire law (gates) | [`LIVE-FIRE-LAW.md`](./LIVE-FIRE-LAW.md) | **LOCKED** |
| 3 | Accessible loan (Morpho RSS → spendable USDC) | [`ACCESSIBLE-LOAN.md`](./ACCESSIBLE-LOAN.md) | Script shelf — needs pool idle |
| 4 | Token as capital (RSS budget) | [`TOKEN-AS-CAPITAL.md`](./TOKEN-AS-CAPITAL.md) | Doctrine |
| 5 | Whale USDC depth (cbBTC book) | [`WHALE-ENG-BRIEF.md`](./WHALE-ENG-BRIEF.md) | Plan — needs cbBTC |

---

## Scripts that exist — **NOT live until King fires named plan**

| Script | Tied plan | What it would do |
|--------|-----------|------------------|
| `FireAeroIgnition.s.sol` | CREATE-OPPORTUNITIES | Create RSS/USDC Aero pool ± thin LP seed |
| `FireUseRssMorpho.s.sol` | ACCESSIBLE-LOAN / use RSS | Post RSS + borrow pool idle → hot |
| `FireKingdomOps.s.sol` | Ops strike | Loop fund / arm / slash / BRETT zero |
| `FireSlashDutch.s.sol` | Spoils | Reset Dutch floor |
| `FireZeroBrettDust.s.sol` | Debt law | Clear ~$0.30 BRETT dust |
| `kingdom-robot.sh` | Ops daemon | Watch/fire only with AUTO_FIRE=1 + King gates |

---

## Already live on Base (prior fires — not new)

Desk · Bond · Dutch · First Whale · Spoils router · yRSS · RSS77/RSS91/BRETT Morpho · extract fortress done.

**No new live until King reads and fires.**

---

## How King unlocks a live step

1. Read the plan doc above  
2. Say which plan + size (e.g. “FIRE CREATE pool only” / “FIRE Ignition seed $1 + 100k RSS”)  
3. Explicit **KING_OK / KING_GO / FIRE_*** for that action  

Scribe dry-runs and builds until then.
