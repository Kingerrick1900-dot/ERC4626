# ORACLE POWER MOVE — Fixed $1 (burned)

**STATUS: FIRED LIVE (2026-07-21).** Steps 2–4 executed on Base. Credit line armed.  
`LIVE-FIRE-LAW.md`

---

## What the oracle is for

| | |
|--|--|
| Oracle | `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` |
| Mark | **$1.00 per RSS** — immutable (owner **dEaD**) |
| Job | Price RSS as Morpho **collateral** so Kingdom can **borrow USDC** |
| Power | Market price of RSS is irrelevant on this book. Credit runs off **$1**. |

That is the power move: **treat RSS as $1 bank collateral and draw against it.**

---

## The move (one sequence)

1. **Post RSS** on RSS77 (and optionally RSS91) — warehouse the $1 line on-chain  
2. **Borrow max idle USDC → Hot** — exercise the oracle (spendable cash)  
3. **Leave debt open** — capacity stays armed; no fortress; no yRSS lock  

| Size | Soft capacity @ 70% LTV |
|------|-------------------------|
| Post **1M RSS** | ~**$700k** |
| Post **ALL ~16.7M RSS** | ~**$11.7M** |

**Today’s draw:** pool idle ≈ **$1–$2** total. Power move still **posts the line** (visible Morpho position at $1 mark). Cash draw scales when USDC is supplied into **this** oracle market.

---

## Why this is the power move (not theater)

- Oracle already burned — **cannot be contested**  
- Collateral post = **on-chain proof** of Kingdom credit at $1  
- Same oracle that cleared ~**$9M** util before — the mark works  
- No desk buyer, no “bring capital” speech — **inventory → credit**  

Secondary (after FIRE): yRSS/PA may route USDC into this book; bribes/DEX optional. **Primary is the oracle draw.**

---

## Fire (when King orders)

```bash
# POWER MOVE — post ALL RSS, borrow all idle to Hot
KING_OK=1 KING_GO=1 FIRE_RSS=1 POST_ALL=1 MIN_BORROW=1 \
  forge script script/FireUseRssMorpho.s.sol --rpc-url $BASE_RPC --broadcast --slow -vv
```

Optional: `POST_RSS=1000000ether` for 1M only.  
Optional: `USE_RSS91=1` (default) splits across 77% + 91.5% books.

**Gates:** `KING_OK` · `KING_GO` · `FIRE_RSS` · hot `PRIVATE_KEY`

---

## Done looks like

| Check | Pass |
|-------|------|
| Morpho RSS coll posted | > 0 (ideally ALL free RSS) |
| Hot USDC | +idle borrowed (even if small today) |
| Debt shares | > 0 only for real borrow (access law: cash landed) |
| Oracle | still $1 — unchanged |

**King one-liner:** *We use the $1 oracle for credit. Post RSS. Draw USDC. That is the power.*
