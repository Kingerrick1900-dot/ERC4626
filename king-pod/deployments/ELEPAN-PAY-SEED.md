# ELEPAN OPTIMAL PAY LOOP — PLAN ONLY (NO FIRE)

**Status:** PLAN. Circular FeeSeed = **not optimal.** This doc replaces it as the primary pay design.

**Verdict:** Optimal Morpho pay is **external depth + borrow→redeploy carry**, not self-skim on a matched book.

---

## Why FeeSeed / 100% util self-loop is suboptimal

| | Circular FeeSeed (A) | Optimal |
|--|--|--|
| Who pays interest | Hot pays itself | External borrowers / King carry sink |
| Landing fee | 10% of **own** supply interest (crumbs) | 10% of **outsider** vault interest (AUM scale) |
| Hot PnL | Usually **net cost** (borrow ≥ supply) | **Spread** if redeploy APY > borrow APY |
| What majors run | Bootstrap optic only | Deposit→borrow→redeploy→repeat (MORE / desks / Coinbase-shaped) |
| Morpho “allows it” | Yes — doesn’t make it optimal | Same |

yRSS `$9M` matched magnet was **depth/optics**. Do not dress it as the earn engine.

---

## Optimal machine (copy-cat that pays)

```
EXTERNAL USDC → yELEPAN-USDC → supplies Elepan/USDC market (true idle)
                                    ↓
HOT posts Elepan collateral → borrow USDC (loan that must earn)
                                    ↓
Redeploy USDC → Morpho USDC vault sink (Steakhouse / Gauntlet-class)
                                    ↓
Earn: (sink APY + incentives) − borrow APY − fees > 0
Landing: 10% of yELEPAN interest from EXTERNAL suppliers (real AUM fee)
```

Same pattern retail/MORE/institutions use. Kingdom already has the curator seat (moat + yVault + PA). Missing piece = **external idle**, not a fatter self-loop.

### Pay pockets (ranked)

1. **Curator AUM fee** — outsiders deposit yELEPAN-USDC → Landing gets 10% of their yield (**primary scale**).  
2. **Carry spread** — King borrow → foreign Morpho USDC vault when sink &gt; borrow (**loan that earns**).  
3. **Circular fee skim** — last resort optic only; **do not optimize for this**.

---

## Phase plan

### P0 — Rails (DONE)
Moat, yELEPAN-USDC (fee→Landing, $14M cap, $700k PA), Elepan bag on hot, V2/sleeve/ZK for external inflows.

### P1 — External depth (OPTIMAL SEED) — no circular $9M
| Move | Action |
|--|--|
| P1a | Publish yELEPAN-USDC + FHE/sleeve/ZK deposit addresses |
| P1b | Route first real USDC in (depositors / desk / King external) — **supply-only**, no matched borrow |
| P1c | Optional **smoke optic only** (≤$500k BufferSeed) if King wants UI util — **not** the pay engine |

Kill: Fortress/Cap circular self-seed as “earn.”

### P2 — Earning loan (CrownElepanCarry)
When market idle ≥ ask:

```
supplyCollateral(Elepan)
borrow(USDC, ask)                    // soft LTV ≤70%, HF ≥1.55
deposit(USDC) → SINK Morpho vault    // whitelist only
```

**Sink whitelist (Base — from Kingdom sheet; APY checked at GO):**
| Sink | Address |
|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` |
| Steakhouse USDC | `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` |
| Steakhouse HY USDC | `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F` |

**Fire rule:** `sinkAPY (+ incentives) ≥ borrowAPY + 150bps` or abort. Morpho flash optional to pack collateral+borrow+deposit atomic (MORE-shaped) — still work-or-revert.

### P3 — Scale
Idle ↑ from externals → raise ask → loop count 1→3 max while HF≥1.55.  
PA stays curated ($700k until GO). Landing fee shares grow with **AUM**, not with self-debt.

---

## What we build (on GO) — not FeeSeed

| Contract / script | Role |
|--|--|
| `CrownElepanCarry` | Coll→borrow→sink deposit; HF + APY gate |
| `FireElepanCarry.s.sol` | `KING_GO` / `ASK_USDC` / `SINK` / `LOOPS` |
| Fork harness | Revert if spread negative; unwind path |

**Deprioritize:** `CrownElepanPaySeed` FeeSeed 100% util.  
**Optional tiny:** BufferSeed smoke ≤$500k optic only if King insists on non-zero util before first depositor.

---

## Curator rules (unchanged discipline)

Soft LTV ≤70% · HF ≥1.55 · PA $700k until GO · fee 10%→Landing · no invented incentive APYs · no RSS recycle.

---

## Decision ask (King)

1. Confirm: **optimal = external depth + Carry to Steakhouse/Gauntlet** (FeeSeed demoted)?  
2. First idle source: **publish & wait** · **King brings USDC supply-only** · **smoke ≤$500k optic**?  
3. Preferred sink for first carry (or “pick best APY at fire time”)?  
4. **GO** → build Carry + fork spread check — **no** Fortress circular seed
