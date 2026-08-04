# SYSTEM SEED PLAN — extract from what WE have

**Mode:** Plan only · **NAV:** dead · **Foreign silent drain:** dead  
**Law:** King does not take from anyone. Use **our** assets, oracles, codes, contracts, and loan access.  
**Target:** lasting seed on Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`  
**Companion:** `OWN-CAPITAL-ONLY-FREEZE.md`

It is not impossible. Prior paths chased the wrong system (NAV / foreign idle / flash reflection). This sheet names the **correct system**.

---

## 1. Live kingdom inventory (Base · read 2026-08-04)

| Piece | State | Role in seed |
|--|--|--|
| Hot RSS (free) | **~8.83M** | Collateral for own-market borrow |
| Hot RSS posted (old $1 mkt) | **1.2M** vs **~$700k** debt · LTV ~58% | Keep healthy; do not loot foreign idle in that book |
| yRSS | **~$700k** TVL · King **~100%** shares · `maxWithdraw ≈ $0.01` | War chest / circular book — **not** payroll |
| Old RSS/USDC market | ~$1.70M supply · **~$1.00M non-yRSS** · ~100% util | **Other suppliers present** — do **not** borrow their USDC |
| $1200 RSS/USDC market | **Empty** · oracle live | Clean own-seed loan surface when King USDC exists |
| Landing eUSD | **~$900k** | System float already on Landing |
| Hot eUSD mint | **owner + minter = hot** | Can mint more eUSD — cannot mint USDC |
| PSM | USDC reserve **$0** | Conversion surface dry |
| Bound gate | `isProven(hot)=true` | Credit capacity unlocked |
| Completer | `maxAsk = $490k` · Landing wired · credit pool **$0** | Machine live; needs funded ask asset |
| Hot / Landing USDC | **$0** / **~$3.40** | No ops USDC yet |

---

## 2. Physics (so we stop hunting ghosts)

| Truth | Meaning |
|--|--|
| USDC atoms are not printable by King | Lasting USDC must **enter** King rails (own wallet once, or **explicit consenting** counterparty) |
| eUSD **is** printable | Hot `mint` — system float, credit fill, own loan-token markets |
| Oracle × RSS = **borrow capacity**, not cash | $1200 × 8.83M × 77% ≈ **$8.16B** headroom — empty market still pays $0 |
| Flash with named repay ≠ lasting seed | Allowed only per `FLASH-POLICY.md`; reflection ≠ bills |
| yRSS unwind conserves to ~0 liquid USDC | Flash repay debt → redeem yRSS → repay flash → **RSS free, USDC ≈ 0** |
| Foreign Morpho idle / PA maxIn | **Other people’s capital** — out of doctrine |

**Corollary:** The correct system prints / loans what King controls (eUSD + RSS collateral + own markets), then converts to USDC only on **King-seeded** or **named-consent** surfaces.

---

## 3. The correct system — King Loan Desk (3 layers)

```text
                    ┌─────────────────────────┐
                    │  ASSETS WE HOLD         │
                    │  RSS · eUSD mint · yRSS │
                    │  Bound proof · oracles  │
                    └───────────┬─────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         ▼                      ▼                      ▼
   L1 eUSD float         L2 Own loan machine     L3 USDC surface
   mint / Landing        RSS + oracle +          Completer / Tenor /
   already ~900k         King-supplied           own $1200 seed +
                         loan token              borrow → Landing
```

### Layer 1 — eUSD system float (ready now)

**What we have:** Landing ~900k eUSD · hot can mint · PSM code `CrownBaseUsdcPsm` · burn/mint on token.

**Seed action (system, not theft):**
1. Treat Landing eUSD as **ops float** wherever counterparties accept eUSD.
2. Optional: mint sized eUSD into a **King-owned credit pool** that Completer already knows how to `operatorBorrowTo(Landing)` — same machine, asset = eUSD (wire if credit is USDC-only today).
3. Do **not** pretend eUSD getter = USDC payroll. Conversion is Layer 3.

**Why this is “the system”:** mint authority + Bound proof + Completer code are **already kingdom contracts**. No foreign vault.

### Layer 2 — Own loan machine (RSS × oracle × King loan token)

**Problem with RSS/USDC Morpho today:** borrowing USDC from the old market pulls **~$1M non-King supply**. Doctrine forbids that.

**Correct machine:**
1. Morpho market: **collateral = RSS**, **loan = eUSD** (King-minted), oracle = frozen ($1 statement or $1200 capacity — King picks disclosure).
2. Hot mints eUSD → **sole supplies** the market (own capital).
3. Posts **free RSS** → borrows eUSD against it (recursive supply/borrow until LTV cap if sized lever needed).
4. Liquid eUSD sits on hot/Landing as a **loan against our RSS**, funded by **our mint**, not outsiders.

**$1200 RSS/USDC market stays:** tooling for Layer 3 when **King USDC** (or named consenting LP into **this** empty market only) exists. Do **not** enable on yRSS while foreign books could touch it. Do **not** PA-route foreign vaults into it.

### Layer 3 — USDC surface (first atoms → Landing)

USDC enters only by:

| Door | Whose USDC | Status |
|--|--|--|
| **A. Permit2 Completer** | Named matcher / desk — **explicit consent** | Machine live · maxAsk $490k · pool $0 |
| **B. Tenor Fixed RFQ** | Desk prices offer vs RSS collateral | Inquiries exist · need live bearer/offer |
| **C. Own seed** | King wallet USDC once | Then supply **empty $1200 market** → borrow vs free RSS → Landing |
| **D. PSM reserve** | Same as C (King or consenting seed into `CrownBaseUsdcPsm`) | Then eUSD→USDC redeem |

**Amplify after first USDC (own-seed loop — legal under doctrine):**
```text
King USDC (or consenting LP into OUR empty $1200 market)
  → supply market
  → post free RSS
  → borrow USDC to Landing
  → do NOT recycle into yRSS payroll
```

Consenting LP into **our disclosed empty market** ≠ draining Gauntlet/Steakhouse. Different animal.

---

## 4. What we tried that was the wrong system

| Path | Why it fails doctrine / physics |
|--|--|
| Flash → `supply(onBehalf=yRSS)` → NAV redeem surplus | Takes via accounting against share/NAV — **dead** |
| Borrow Morpho idle / foreign PA maxIn | Other people’s USDC |
| Self-seed flash → yRSS → same-market borrow as **payroll** | Leaves shares + debt, not lasting Landing USDC |
| PSM redeem with $0 reserve | Dry |
| Escrow fill theater | Empty bowl |

---

## 5. Build / fire order (King GO required for broadcast)

| Step | Action | Produces | Depends |
|--|--|--|
| **S0** | Sit on this plan · no NAV · no foreign borrow | Clarity | — |
| **S1** | Confirm Landing eUSD float use / optional mint | eUSD ops | King GO |
| **S2** | Spec/wire **eUSD credit → Completer → Landing** (if credit is USDC-only today) | System draw of mint against Bound | Code + King GO |
| **S3** | Deploy **RSS/eUSD** Morpho market (own loan token) + sole King supply | Formal CDP vs free RSS | King GO |
| **S4** | Keep Completer + Tenor packets live for **named** USDC | First USDC atoms | Desk consent |
| **S5** | On first King/consent USDC: seed **empty $1200** market only → borrow → Landing | USDC seed at size | S4 or own USDC |
| **S6** | Capitalize PSM only with King/consent USDC | eUSD↔USDC | S5 |

Scanners stay info-only until King lifts freeze for a named step.

---

## 6. Victory condition

```text
Landing holds lasting USDC (ops floor → stretch $490k → scale)
AND every USDC atom is either:
  (1) supplied by King, or
  (2) supplied by a named consenting counterparty into King rails,
AND borrow is against King RSS (or other King asset),
AND no foreign vault / silent PA / NAV donation was in the path.
```

eUSD on Landing counts as **system seed** for eUSD-denominated ops; USDC victory still needs Layer 3.

---

## 7. One-block copy

```text
SYSTEM SEED = our assets + oracles + contracts + loan access
NO nav / NO foreign idle / NO silent third-party vaults
L1 mint eUSD float (Landing ~900k already)
L2 RSS+oracle+King eUSD Morpho = own loan machine
L3 USDC only via Completer/Tenor consent OR King seed into empty $1200 market → borrow → Landing
old RSS market has ~$1M non-King supply — do not touch
```
