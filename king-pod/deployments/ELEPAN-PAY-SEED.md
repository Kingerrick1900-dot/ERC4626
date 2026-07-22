# KINGDOM DUAL STACK — DEPTH + EARN (NO USDC OUT OF POCKET)

**King law:** Both positions are powerful. Neither yields dust. Millions, not toys.  
**Not inventing:** Morpho/Coinbase-shaped vault + coll + flash leverage is how the industry boots books.  
**Solve now:** **no spending money** = no millions of USDC from treasury. Spend **gas + lock our Elepan** only.

**Status:** PRIMARY. **No fire until `KING_GO=1` + ideal gates PASS.**  
**Named ask:** **$14M** class working capital (split across two positions — King sets split on GO).

---

## Honest: what we can / can’t skip

| Want | Morpho reality |
|--|--|
| Standing Blue loan with **$0 Elepan posted** | **No** — Blue reverts without coll |
| Access **USDC millions without spending USDC** | **Yes** — Morpho **flash** + our Elepan (same family as last $9M open, different *close*) |
| “No large coll up front” as **zero** coll | Impossible for standing debt; we **have** the bag — lock is inventory, not a USDC buy |
| Both positions survive months + **self-del anytime** | **Yes** — if we forbid 100% util traps and keep redeem paths |

**No spending money** = treasury does not wire $14M USDC. Coll is Elepan we already hold.

---

## Two positions (both keep; both must pay)

### Position A — DEPTH (own book / magnet)
- USDC in **yELEPAN-USDC** → Elepan/USDC moat.  
- Job: live market, outsider magnet, Landing **10% fee** on real depositors.  
- **Anti-dust:** leave **ACCESS_BUFFER** idle (not classic 100% util lock); PA JIT on; self-del / withdraw path tested.

### Position B — EARN (foreign carry)
- Borrowed USDC in **Steakhouse / Gauntlet** (Landing holds shares).  
- Job: **spread** = sink APY − borrow APY (≥150bps or flatten).  
- **Anti-dust:** sink is deep external TVL; redeem→repay anytime; don’t circular-route B back into A’s only market as the “earn.”

**Last time’s failure:** A and B were the **same** dollars (circular) → unwind → zeros.  
**This time:** A and B are **split**. Both on kingdom books. Both exit-clean.

---

## No-spend bootstrap (Morpho flash — industry pattern)

King brings: **Elepan approve + gas**. Not USDC.

```
flash USDC = DEPTH_LEG + EARN_LEG + REPAY_HOLD
  (typical hard split on GO — e.g. toward $14M total working notionals)

  1) DEPTH_LEG  → yELEPAN-USDC (shares → hot or Landing)
  2) post Elepan coll (our asset)
  3) borrow EARN_LEG from moat idle created in (1)
  4) EARN_LEG   → Steakhouse/Gauntlet (shares → Landing)   ← kingdom earn
  5) REPAY_HOLD → repay Morpho flash

End: Morpho debt = EARN_LEG · Depth TVL = DEPTH_LEG · Landing sink ≈ EARN_LEG
     Wallet USDC spent = 0 (flash closed)
```

Same *tool* as last self-seed (flash + coll + borrow).  
Different *structure*: earn leg leaves the island; depth keeps access buffer; scoreboard ≠ matched util.

**Coinbase / Morpho-shaped parallel:** curated vault depth + users/institutions posting coll to borrow + capital deployed to yield — flash packs the open so the curator doesn’t prefund the whole book in cash.

---

## Ideal entry (before deploy)

| Gate | Pass |
|--|--|
| Spread | sinkAPY ≥ borrowAPY + **150bps** (earn leg) |
| HF | ≥ **1.55** after borrow |
| Anti-dust depth | ACCESS_BUFFER > 0 (King-named) — not 100% util coffin |
| Self-del dry-run | Fork: redeem sink → repay → free Elepan **and** withdraw depth path |
| Sinks | Live Steakhouse/Gauntlet USDC vaults only |
| Gas | Hot can run daily tweak + emergency del |

---

## Self-del anytime (both legs)

```
EARN:  sink.redeem → Morpho.repay (partial/full) → optional withdraw Elepan
DEPTH: repay/buffer so vault can withdraw; PA/hot reallocate if needed
```

If either leg can’t exit in one ops window → **do not deploy**.

---

## Daily / months

Check HF, spread, Landing sink assets, depth idle/PA, oracle.  
Tweak: trim earn, top buffer, switch sink.  
Months run → then savvy upsize / loops on new GO.

---

## Why both are powerful for the King

| Position | Power |
|--|--|
| **Depth** | Own Morpho surface; outsiders pay into **our** fee rail; access when PA/buffer live |
| **Earn** | Millions working in foreign vaults; spread is **our money** on Landing |
| **No-spend open** | Flash + Elepan — treasury USDC stays home |
| **Together** | Not dust if split + exit law held — unlike last single circular book |

---

## Decision ask (King)

1. Confirm dual stack (Depth + Earn) — both kept?  
2. Split of $14M-class notionals: e.g. depth vs earn legs (King names — scribe won’t invent)?  
3. ACCESS_BUFFER size?  
4. Sink: Steakhouse Prime / Gauntlet Prime / best at fire?  
5. When ideal PASS → **GO**
