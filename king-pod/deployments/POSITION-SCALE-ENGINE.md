# Position → Scale Engine (LIVE BOOK)

**No live fire without King GO + phase flag.**  
**Not a plan:** “once outside money arrives.”  
**This plan:** engineer scale from the **current debt position + Elepan inventory** you already hold.

---

## 0) Live book (Base, now)

| Line | Amount | Where |
|--|--|--|
| CDP collateral | **25.2M Elepan** | `0x46b1D159…1174` |
| CDP debt | **13.000000948M eUSD** | same CDP |
| HF | **1.938** (floor 1.55 / LR 1.50) | not liquidatable |
| Max withdraw (no repay) | **~5.05M Elepan** | keeps HF ≥ floor |
| Max mint headroom | **~3.26M eUSD** | do **not** mint until convert exists |
| Landing eUSD | **13.0M** | cold treasury (matches debt principal) |
| Free Elepan (hot) | **~74.72M** | ops wallet |
| Liquid USDC (hot+Landing) | **~$3.65** | not payroll |
| yELEPAN-USDC / Morpho idle | **~$2** | rails live, book empty |

**Balance-sheet read (one economic King):** Landing’s 13M eUSD and CDP’s 13M debt are the **same issuance loop**. Net real inventory ≈ **99.9M Elepan** (25.2 locked + 74.7 free) + dust USDC. Soft $1 oracle on the moat.

---

## 1) What the position can do without praying

| Lever you already have | Engineered use |
|--|--|
| Free **74.7M Elepan** | Incentive budget + Morpho collateral |
| CDP **5.05M** withdrawable | Extra Morpho coll without touching debt |
| Landing **13M eUSD** | Repay valve / future PSM inventory (not USDC) |
| Own vault **yELEPAN-USDC** | USDC magnet you curate |
| Morpho Elepan/USDC + borrow script | Turn idle USDC → Landing cash against Elepan |
| Self-liq + ACCESS CLAUSE | Safety + cold mint discipline |

Physics: you cannot invent USDC from empty Morpho. You **can** spend **your Elepan** as customer-acquisition capital into **your** vault so USDC shows up as a **result of your emission engine**, not as a precondition.

---

## 2) Engine (three machines, in order)

### M1 — Own emission engine (uses YOUR bag, not Merkl’s whitelist)
Deploy **Kingdom** reward distributor (streaming or epoch Merkle) that pays **Elepan from hot** to addresses that deposited USDC into **yELEPAN-USDC**.

- Budget from free Elepan (King sets size; example probe: 4M / 4 weeks — same number, **your contract**).
- No Angle registry. No Notion form. King controls pause, rate, blacklist.
- Merkl stays optional amp **only if** whitelist ever clears — never blocks M1.

**Why this is position-native:** you’re converting idle Elepan inventory into vault TVL demand.

### M2 — Collateral engine (debt position stays healthy)
Keep CDP HF ≥ 1.55. Do **not** mint more eUSD until M3 convert works.

Post Morpho collateral from:
1. Free hot Elepan (primary), and/or  
2. CDP `withdraw` up to ~5.05M if more Morpho coll is needed.

Only if King wants max Morpho surface: partial `repay` from Landing eUSD → free more CDP Elepan. That **shrinks issuance**; treat as a deliberate restructure, not default.

When vault idle ≥ King floor → `FIRE_BORROW` Elepan coll → **USDC to Landing** (existing script pattern). First USDC is **earned by M1 + borrow**, not hoped.

### M3 — Convert engine (makes the debt book useful)
`CrownEusdPsm`: eUSD ↔ USDC around soft peg, fees → Landing.

- Seed PSM reserve from **first Landing USDC** (M2), not from fantasy.
- Until PSM is live: **no new CDP mint**. Existing 13M eUSD stays treasury inventory.
- Optional parallel: `KingElepanSale` escrow for **named** Elepan bids (engineered OTC desk, sized tranches). Not a pool dream.

---

## 3) Sequence (engineered, GO-gated)

| Step | Action | Uses from book | Flag |
|--|--|--|--|
| S0 | Spec/deploy Kingdom Elepan emitter → yELEPAN depositors | free Elepan | `FIRE_EMITTER=1` |
| S1 | Fund emitter budget (King names units) | free Elepan | `FIRE_EMIT_FUND=1` |
| S2 | Post Elepan as Morpho coll (hot / optional CDP withdraw) | 74.7M ± 5.05M | `FIRE_COLL=1` |
| S3 | When idle ≥ floor: borrow USDC → Landing | coll + vault TVL | `FIRE_BORROW=1` |
| S4 | Deploy PSM; park tranche of Landing USDC as reserve | Landing USDC + eUSD | `FIRE_PSM=1` |
| S5 | Only then consider extra CDP mint into Landing | mint headroom | `FIRE_MINT=1` |

Silence ≠ GO. No step broadcasts without its flag.

---

## 4) Debt rules (real position, not vibes)

1. **HF floor 1.55 hard.** Self-liq remains the escape under 1.50.  
2. **Landing eUSD exists to backstop repay / PSM — not to cosplay USDC.**  
3. **Don’t grow debt until convert (M3) can clear it to spendable cash.**  
4. **Emission spend is capped by free Elepan King names** — never by CDP coll.  
5. **Scoreboard:** Landing USDC · yELEPAN TVL · Morpho idle · CDP HF · emitter Elepan left.  

---

## 5) One-line plan

> Take the **99.9M Elepan book**, run an **owned emitter** into **your USDC vault**, **borrow against Elepan** into Landing, then **PSM the eUSD debt stock** into that USDC — scale the position you have, don’t wait for a stranger’s money to start.
