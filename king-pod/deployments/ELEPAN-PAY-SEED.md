# ELEPAN OPTIMAL PAY LOOP — APOLLO / AARNÂ COPY (PLAN ONLY)

**Status:** PLAN. No fire until King GO.  
**Gold standards:** Apollo ACRED-on-Morpho · aarnâ âtvUSDC bounded carry loop.  
**Demoted:** circular FeeSeed / 100% util self-skim.

---

## What the majors actually run

### Apollo (ACRED → Morpho)
Morpho’s own story: tokenized Apollo private credit (**ACRED**) used as **Morpho collateral** → borrow stablecoins → capital-efficient **loop** that captures:

```
ACRED yield  −  stablecoin borrow cost  =  spread (the pay)
```

Gauntlet/Securitize automates: post ACRED → borrow USDC → buy more ACRED → redeposit → repeat under risk caps.  
Morpho turns a **yield-bearing** position into productive coll + leverage. Not a matched self-lend magnet.

### aarnâ (âtvUSDC)
USDC vault routes into **Morpho / Aave / Pendle** to stack base lending (+ PT basis when fat).  
When **carry is clearly positive**, run a **bounded single-collateral Morpho loop** (soft ~70% LTV).  
Target band **~8–12% APY** on USDC in normal markets. Agent enforces allowlists, depth, LTV — no degen pyramids.

**Shared law both use (we copy this, not FeeSeed):**
1. Collateral or deployed asset has **real external yield**  
2. Borrow stables only when **spread &gt; 0** (with buffer)  
3. **Bounded** leverage (LTV / loop count / HF)  
4. Curator/vault policy sits **above** the loop

---

## Kingdom map (Elepan stack)

| Major piece | Elepan analog | Status |
|--|--|--|
| Apollo: yield-bearing coll on Morpho | Elepan/USDC moat (soft $1) — coll is **peg inventory**, not private-credit NAV | Market live; yield is on the **borrow redeploy**, not on Elepan coupon |
| Apollo: borrow USDC against coll | Hot posts Elepan → borrow USDC | Needs **true idle** in market |
| Apollo: buy more yield asset / loop | Redeploy USDC → Steakhouse/Gauntlet (or later PT/Pendle) · optional buy-more only if King wants bag leverage | Carry contract — build on GO |
| aarnâ: vault routes to Morpho+ | yELEPAN-USDC → Elepan/USDC book (+ sleeve→WETH MM/V2 already) | Vault live; extend sinks on GO |
| aarnâ: loop only if carry+ | `spread = sinkAPY − borrowAPY ≥ 150bps` or abort | Hard gate in Carry |
| aarnâ: ~8–12% target band | Same **band as goal**, not a promise — only fire when live rates clear | Rate check at fire |
| Curator AUM fee | yELEPAN 10% → Landing | Wired |

**Honest gap vs Apollo:** ACRED **is** the yield. Elepan is soft-$1 collateral. Our “ACRED yield leg” = **whatever we buy/redeploy with the borrowed USDC** (Morpho USDC vault / PT), not an Elepan coupon. Same loop shape; different yield source.

---

## Optimal machine (locked)

```
EXTERNAL USDC → yELEPAN-USDC → Elepan/USDC idle     (aarnâ base depth / curator AUM)
        ↓
HOT: supplyCollateral(Elepan) → borrow USDC         (Apollo coll→borrow)
        ↓
ONLY IF carry+: deposit USDC → SINK (Steakhouse/Gauntlet/…/later Pendle PT)
        ↓
Bounded loops (1–3), soft LTV ≤70%, HF ≥1.55      (aarnâ guardrails)
        ↓
Pay = sink yield − borrow cost (+ Landing 10% on outsider vault interest)
```

### Pay pockets (ranked)
1. **Landing AUM fee** on external yELEPAN deposits  
2. **Carry spread** on the earning loan (Apollo/aarnâ)  
3. Circular FeeSeed — **optic only**, ≤$500k smoke if King insists; never the engine

---

## Phase plan

| Phase | Action | Mirror |
|--|--|--|
| **P0** | Rails live (moat, yVault, PA, fees) | Curator seat |
| **P1** | External USDC in (publish / desk / King supply-only) — **no** Fortress circular | aarnâ vault fill |
| **P2** | `CrownElepanCarry`: coll→borrow→sink when spread≥150bps | Apollo loop + aarnâ bound |
| **P3** | Scale ask + loops 1→3 as idle grows; optional Pendle/PT sink later | aarnâ stack |

### Sink whitelist (Base — APY at fire time)
| Sink | Address |
|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` |
| Steakhouse USDC | `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` |
| Steakhouse HY USDC | `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F` |
| Later | Pendle PT / âtv-style router — only after King GO |

### Fire rules (non-negotiable)
- `sinkAPY (+ incentives) ≥ borrowAPY + 150bps` else revert  
- Soft LTV ≤70% · HF ≥1.55 · max loops 3  
- Morpho flash optional for atomicity — work-or-revert  
- No invented APYs · no RSS recycle · no FeeSeed Fortress

---

## Build on GO
`CrownElepanCarry` + `FireElepanCarry.s.sol` + fork: negative spread reverts, unwind works, Landing fee path untouched.

---

## Decision ask (King)
1. Lock gold standard = **Apollo coll→borrow→yield loop** + **aarnâ carry-only-when-positive**?  
2. First idle: publish & wait · King supply-only · smoke ≤$500k optic?  
3. First sink: best APY at fire · or name one?  
4. **GO** → build Carry (not FeeSeed)
