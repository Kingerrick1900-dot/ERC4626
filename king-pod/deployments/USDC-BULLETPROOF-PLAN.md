# USDC BULLETPROOF PLAN — King Errick

**Mission:** Spendable USDC on Landing so bills get paid.  
**Fail state:** Kingdom starves. **Win state:** Landing funded → ops + reinvest → reign.  
**Law:** Elepan free. Loan ≠ dump RSS/Elepan. No yRSS self-loop as “payroll.” Flash ≠ lasting cash.

---

## Live board (truth)

| Holding | State | Can it pay bills? |
|--|--|--|
| Bound gate | **Proven $700k** | Unlock only — not cash |
| Completer / AutoDraw | **Operators live · maxAsk $490k** | **YES if credit has USDC** |
| Credit pool | **$0** | No |
| Hot USDC | **$0** | No |
| Hot eUSD | **~$900k** | Not until redeem/DEX depth |
| Free RSS | **~13.8M** | Collateral for borrow/RFQ |
| Morpho debt / posted | ~$700k / 1.2M RSS | Healthy LTV |
| yRSS war chest | ~$700k TVL | Nation TVL — not payroll |
| Tenor RFQs $500k RSS | **Live · no offer yet** | YES if desk prices |
| Aero RSS/USDC | **~$1 USDC** | Dust only |
| PSM eUSD→USDC | **~$0.14 reserve** | Dust only |

**Physics line:** Reflecting liquidity (flash/`balanceOf` in-block) ≠ Landing seed. Lasting USDC must come from a **counterparty** or **convertible inventory with depth**.

---

## Victory condition

```
Landing USDC ≥ $100k (ops floor) → stretch $490k (Bound maxAsk) → scale
AND that USDC is NOT recycled into yRSS / same Morpho market
```

---

## Stacked offense (run ALL tracks — first cash wins)

### TRACK A — Permit2 / matcher Completer (PRIMARY · fastest legal)

**Why bulletproof:** Machine already live. Outside USDC → `complete(amount)` → Landing same block. King debt on credit ≤ $490k.

| Step | Action | Owner |
|--|--|--|
| A1 | Ship Completer + Permit2 pull — **DONE LIVE** `0xA247c1d0Ad4E7690764E456E5d8d315bA2912468` operator=true | Chief |
| A2 | Packet to Armitage / Wintermute / DWF / any USDC desk: “approve Completer or Permit2; call `complete(≤490000e6)`” | King + Chief |
| A3 | `--watch --fire` on hot USDC / credit USDC already armed (`FireFundBoundCredit.py`) | Chief |
| A4 | On fill: USDC stays on Landing; book credit debt; schedule repay from ops yield | King |

**Kill:** No matcher in N polls → keep watching; do not fake with Morpho flash into Completer (flash repay zeros Landing).

**Scripts:** `FireFundBoundCredit.py` · Completer `0x3827…F7C6` · Credit `0x20B1…7D1A`

---

### TRACK B — Tenor Fixed RFQ accept (PARALLEL · already fired)

**Why:** True RSS collateral, desk prices onchain, USDC to hot → route Landing.

| Step | Action |
|--|--|
| B1 | Keep inquiries live: Armitage `7e35d157-…` · Broadcast `caaa6250-…` |
| B2 | `WatchTenorRfq.py --poll` — on offer ≥ $100k accept immediately |
| B3 | Post-fill: hot → Landing; **never** deposit to yRSS |

**Kill:** Elepan never in collateral. If only Elepan offers appear → reject.

---

### TRACK C — Capitalize eUSD → USDC depth (PARALLEL · inventory unlock)

**Why:** Hot already holds ~900k eUSD. Block is redeem/DEX depth, not inventory.

| Step | Action |
|--|--|
| C1 | Seed Base PSM `0xfFEd…4977` with external USDC (or King-named tranche) so `redeem` works |
| C2 | Or stand Aero/Uni eUSD/USDC pool with real USDC deep enough for ≥$100k redeem/swap |
| C3 | Atomic: redeem/swap eUSD→USDC → Completer.complete → Landing |

**Kill:** Do not “value eUSD in a getter” while credit still pays USDC — that lies to the throne. Convert or change credit asset (hard fork) — prefer convert.

---

### TRACK D — Foreign PA / Morpho idle borrow (BACKSTOP)

**Why:** Free RSS is a borrow machine once idle exists.

| Step | Action |
|--|--|
| D1 | Curator packet: Gauntlet/Steakhouse `maxIn ≥ $500k` into RSS market |
| D2 | On maxIn>0: Bundler3 pack / SpoilFire → Landing |
| D3 | Scanner may re-enable Morpho queue **only** as backstop, not primary theater |

**Kill:** No self-supply loop. Borrow receiver = Landing only.

---

### TRACK E — yRSS share secondary (OPTIONAL · not selling Elepan/RSS)

**Why:** War chest is a yield claim someone may buy for USDC.

| Step | Action |
|--|--|
| E1 | OTC packet: yRSS shares at discount for USDC to Landing |
| E2 | Escrow sale contract if King names size |

---

## Forbidden (fail the kingdom)

1. Flash → Completer → Landing → repay flash from Landing (net zero)  
2. Flash/`balanceOf` theater as “funded”  
3. Recycle Landing USDC into yRSS / RSS market  
4. Touch Elepan  
5. Claim eUSD getter = USDC payroll without redeem depth  

---

## Execution clock (Chief default)

| Order | Move | Done when |
|--|--|--|
| 1 | A1 Permit2 Completer wired + matcher packet out | PR merged · emails/RFQ sent |
| 2 | B2 Tenor poll running | offer or idle 24h log |
| 3 | C1/C2 eUSD exit depth named | PSM seed tx or pool LP named |
| 4 | D1 curator packet out | maxIn quote or refuse on record |
| 5 | First green → fire → Landing ≥ $100k | **SEED SECURE** |

---

## Scoreboard (only numbers that matter)

```
Landing_USDC ↑
Credit_debt (King) booked
Elepan_untouched = true
yRSS_recycle = false
```

Not: script count, proven flags, flash TVL mirrors, Aero dust.

---

## One sentence for the King

**Bulletproof = stack matcher Completer + Tenor + eUSD depth + PA borrow; first real USDC to Landing wins; never confuse a flash reflection with a paid bill.**
