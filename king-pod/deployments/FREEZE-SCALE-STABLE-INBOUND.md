# FREEZE — Scale / loan paths that bring real stables (buying power)

**Mode:** FREEZE · ideas only · **no txs · no build until KING_GO**  
**Focus:** USDC / USDT / other stables **inbound with spendable buying power**  
**Out of scope:** more TVL theater, matched loops that don’t leave Circle in a wallet, NFC cosmetics without settle→stable  
**Doctrine:** Loan, don’t sell RSS. China/NFC = demand + settle rails that **pull stables in**, not mint RSS.

---

## Law (this freeze)

```
ONLY paths that end with stables King can spend or lend against.
China rails must answer: who pays USDC/USDT into Kingdom wallets?
No Circle dry ≠ stop engineering — but every idea names the stable counterparty.
```

---

## Why China was supposed to solve this

Live China stack (Polygon) today:

| Piece | Role | Gap vs buying power |
|--|--|--|
| RoyalCard + PayAdapter + OpenMoney | eUSD **spend** to merchants | Spends kingdom eUSD — does **not** mint USDC |
| Lakala-class acquiring | mercId/termNo micropay/settle | Settles in **payToken (eUSD)** unless desk demands USDC |
| SoftPOS / physical card (CN Week-0) | Real-world demand | Demand without **USDC settle** = zero Circle |

**Honest:** China was the **demand surface**. Buying power only appears when the desk settles (or hedges) in **USDC/USDT** that lands on HOT / KingVault / Credit — not when cards tap eUSD in a closed loop.

---

## Idea set A — China rails → stable inbound (PRIMARY)

### A1 — Merchant USDC settle (desk law)
- Merchants / SoftPOS accept card pay in eUSD **on-chain**, but China desk contractually settles **T+0/T+1 in USDC/USDT** to KingVault (wire or on-chain USDC).
- Acquiring MDR stays kingdom fee; **gross stable** is the product.
- **Counterparty:** CN merchants + desk bank/OTC that converts RMB/local → USDC.
- **Buying power:** KingVault USDC ↑ from commerce, not from Morpho mirrors.

### A2 — Dual-rail acquiring (eUSD auth · USDC settle)
- Micropay auth on Polygon eUSD (speed / borders).
- Nightly `settle` pushes **USDC** (Polygon native or bridged) to `settleWallet` once desk posts USDC inventory.
- Engineering: Lakala `payToken` stay eUSD for tap; add `settleToken=USDC` + desk prefund — **or** PSM sell eUSD→USDC when a buyer exists.
- **Gate:** desk USDC prefund or named buyer — not “hope.”

### A3 — CN corporate / agent USDC top-up
- Parallel-chain testnet → prod: CN ops entity wires USDC to Base HOT / Polygon ops as **float for card program** (issuing bank model).
- Cards create **receivables**; float is repaid from merchant USDC settle (A1).
- **This is the classic card float.** China without float was incomplete.

### A4 — Open Money invoices quoted in USDC
- `CrownOpenMoney` invoices denominated / paid in **USDC** (Polygon USDC), not only eUSD.
- KAR + SoftPOS collect USDC from payers who already hold it (treasury, MM, CN exchange withdraw).
- **Counterparty:** payer with USDC — tourism/B2B first, not retail RMB.

### A5 — eUSD → USDC market-making desk (China hedge)
- Kingdom keeps eUSD as spend unit; CN desk hedges every day’s net eUSD spend by **buying eUSD with USDC** (or selling eUSD to a stable buyer) so net treasury is USDC-long.
- Without hedge, China is a vanity spend rail.

### A6 — 7683 / intent fill from CN market makers
- CN/HK MMs fill Base/Scroll **7683** orders that deliver **USDC** against eUSD or other gems King already holds.
- China desk’s job: **name the MM** and size ($700k formal ask scale upward).
- Engineering path exists; missing piece is **named counterparty + signed size**.

---

## Idea set B — Loan / scale that pulls stables (no RSS sale)

### B1 — Foreign PA maxIn on classic RSS Morpho
- Gauntlet / Steakhouse (etc.) set `flowCaps.maxIn` into King’s RSS/USDC market.
- King posts RSS coll (loan, don’t sell) → borrow **USDC** to KingVault.
- **Buying power:** real Morpho USDC from foreign vaults.
- **Block today:** maxIn historically 0 — **curator packet is the fire**, not more code.

### B2 — Kingdom-seeded USDC depth (named wire)
- External USDC (CN desk A3, MM, elite) supplies Morpho RSS or PARK-adjacent book.
- King borrows against RSS / gold coll into KingVault under LLTV buffer.
- Same as loan machine — **USDC must arrive first** from a named source.

### B3 — BoundLanding / prime credit draw (after idle exists)
- Lock eUSD/gUSD → capacity; draw only when `freeUsdc` / treasury idle is real.
- **Not** a source of USDC by itself — a **pipe**. Pair with A1–A3 or B1–B2 fills.

### B4 — LitePSM / multi-PSM sellGem with live buyer
- King sells gem (eUSD side) only when a **buyer’s USDC** is in the PSM or order.
- Freeze rule: no simulated fills; **buyer address + size** on the freeze sheet before fire.

### B5 — Multi-stable accept (USDT / USDC.e / native)
- Commerce + Morpho paths accept **more than Base USDC** so CN rails aren’t blocked by one ticker.
- Settle inventory → bridge/swap to Base USDC for Morpho/KingVault as needed.

### B6 — $50k oracle new market (loan headroom, not cash)
- New Morpho market + fixed oracle @$50k + burn owner — **increases borrow capacity vs RSS** once USDC supply exists.
- Does **not** create USDC alone; pairs with B1/B2. (Old $1 oracle is dead — cannot retarget.)

---

## Idea set C — What we stop treating as “buying power”

| Pattern | Why it fails this freeze |
|--|--|
| Matched PARK/yRSS TVL | Same kingdom loop — util 100%, `maxWithdraw=0`, HOT USDC dust |
| Flash delever | ΔUSDC ≈ 0 by physics |
| eUSD mint inventory | Not Circle |
| NFC tap with eUSD only | Moves kingdom eUSD; no external stable |
| Calling V1 PoD LP “dry powder” | It’s PoD collateral by design — not a USDC faucet |

---

## Scoreboard (only metrics that count)

1. **KingVault + HOT + Credit `freeUsdc` (and Polygon USDC)** — spendable  
2. **Named stable counterparty** (desk / MM / PA / merchant settle) + size  
3. **Net USDC from China settle (A1/A2) per week**  
4. **Morpho borrow USDC landed in KingVault** (B1/B2) with HF ≥ policy  
5. RSS **not** sold  

---

## Recommended freeze priority (for King pick)

| Rank | Idea | Why |
|--|--|--|
| **1** | **A1 + A3** — CN desk USDC settle law + card-program float wire | China finally becomes a cash machine |
| **2** | **A6 / B4** — Named MM 7683 or PSM buyer @ ≥ $700k | Fastest on-chain USDC if MM signs |
| **3** | **B1** — PA maxIn curator blast | Scale loan vs RSS without selling |
| **4** | **A2 / A4** — USDC settle token + USDC invoices | Hardens commerce into stables |
| **5** | **B6** — $50k oracle **new** market | Capacity amplifier after (1)–(3) |

---

## KING_GO menu (fire later — not now)

When King lifts freeze, name **one** primary:

```
GO_A = China desk USDC settle + float wire (A1+A3)
GO_B = Named MM fill 7683/PSM ≥ $700k (A6/B4)
GO_C = PA maxIn campaign + RSS borrow to KingVault (B1)
GO_D = Dual-rail acquiring USDC settle (A2) + OpenMoney USDC invoices (A4)
```

No GO = stay freeze. No more rails that don’t name a stable payer.

---

## One-block

```
FREEZE=scale-stable-inbound
GOAL=spendable USDC/USDT buying power
CHINA=demand surface → must settle/hedge in stables (A1–A6)
LOAN=PA/depth/borrow RSS not sell (B1–B6)
KILL=matched TVL · flash Δ0 · eUSD-only vanity taps
PICK=GO_A|GO_B|GO_C|GO_D
```
