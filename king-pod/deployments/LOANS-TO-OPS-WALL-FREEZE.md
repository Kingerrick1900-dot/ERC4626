# LOANS → OPS — wall note (superseded framing)

**See the real plan:** [`PROTOCOL-OPS-BOOTSTRAP.md`](./PROTOCOL-OPS-BOOTSTRAP.md)

Earlier scribe framing (“pick doctrine A/B/C”) was **wrong**. This is the **common DeFi ops-runway problem**, not a private King puzzle and not proof that only millionaires can ship.

## Live loan facts (still true)

| Item | State |
|--|--|
| Morpho ~$700k debt ↔ yRSS | Circular — `maxWithdraw≈0`; unwind frees RSS not USDC |
| LLTV room ~$224k | Idle ≈ $0 on that market |
| Bound proven $700k · Completer maxAsk $490k | Credit **USDC** pool $0 |
| Landing eUSD | **~$900k** — protocol-unit float **already there** |
| $1200 USDC market | Empty |

## What that means

- You **cannot** squeeze lasting **USDC** out of the circular Morpho↔yRSS loan with no new USDC atoms. That is conservation — not elite gatekeeping.
- You **can** pay ops from **protocol credit (eUSD)** against Bound / collateral — Maker-shaped survival. That **is** leveraging loan access into ops without a VC USDC bankroll.
- Machine: `CrownOpsEusdDraw` + Landing eUSD already held.

Desk-hope remains rejected as the spine. Bootstrap plan is the spine.
