# CHIEF 3-PHASE EXPAND — Both rails · Phase 1 = $500k to Landing

**King Errick of Yahudah · Chief Engineer lock**  
**Order:** Build both (RSS + BRETT). Seed markets. Hunt capital pools. Fees + yield + gov.  
**Hard rule:** **Phase 1 delivers $500,000 USDC to Landing cold.**

---

## North star

| | |
|--|--|
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Phase 1 target | **$500,000 USDC** on Landing |
| RSS Blue | `0x40ac09f3…b794` · $1 oracle burned · **~$14.2M** LLTV power |
| BRETT Blue | `0xf6f43f16…8c16` · 62.5% LLTV · external price |
| Desk | `0xDbf7…065D` · **700k RSS @ $1 LIVE** |
| Vault | yRSS · 10% fee → King · PA rails ~$700k both books |

**Both markets stay. RSS pays Phase 1. BRETT expands the empire.**

---

## PHASE 1 — Bring the King $500k (NOW)

**Goal:** Landing USDC ≥ **$500,000**. Core RSS stack not sacrificed beyond desk slice.

### Dual guns (fire whichever loads first)

| Gun | How | Size |
|-----|-----|------|
| **A — Desk fill** | Counterparty `buyWithUsdc(500000000000)` on live desk | **$500k** exact |
| **B — Blue cash-leg** | Idle ≥ $500k on RSS/USDC → `FireCashLeg500` borrow → Landing | **$500k** |

Desk already holds **700k** inventory — Phase 1 takes **$500k**, leaves **$200k** listed (or pause after fill).

### King actions (human)

1. Send `OPS-COUNTERPARTY-PACKET.md` to one buyer (**Gun A**).  
2. Send `CAPITAL-POOLS-PACKET.md` curator PA ask (**feeds Gun B**).

### Scribe actions (armed)

| Tool | Role |
|------|------|
| Desk LIVE | Gun A settlement |
| `FireCashLeg500` | Gun B (`BORROW_USDC=500000000000`) |
| `FirePositionSeed700k` / PA restore | Pull idle when foreign/yRSS depth appears |
| `phase-expand-status.sh` | Scoreboard |

### Phase 1 exit

Landing ≥ **$500k** → pay burn → optional `desk.pause()` → open Phase 2 with war chest.

---

## PHASE 2 — Seed every Kingdom market + fee/yield engine

**Goal:** Both Blue books have a **USDC face**. Fee meter turns. BRETT rail becomes borrowable.

### 2A — Seed RSS/USDC book

| Action | Detail |
|--------|--------|
| Attract USDC into yRSS | Magnet: util history + $1 oracle moat |
| Allocate into RSS market | Curator reallocate / depositors |
| Keep PA maxIn/Out ~$700k+ | Raise caps when depth grows |
| Recycle Phase 1 slice (optional) | After Landing safe, King may seed **small** USDC back into market to unlock more borrow — only on GO |

### 2B — Seed BRETT/USDC book (both rails)

| Action | Detail |
|--------|--------|
| Acquire BRETT seed | Only with **dedicated** seed USDC (not Landing bills) — DEX has ~$169+ pool depth to start |
| Supply USDC into BRETT Morpho market **first** | Creates idle (lenders / yRSS alloc) — **required before borrow** |
| Then post BRETT collateral → borrow | Conservative LTV &lt; 50%, HF &gt; 1.5 |
| Scripts | `SeedBrettOneUsdc.s.sol`, `ActivateBrettMarket.s.sol`, `DepositYrss.s.sol`, `ArmYrss*` |

### 2C — Fees & yield (turn on the meter)

| Lever | Status / move |
|-------|----------------|
| yRSS performance fee | **10% LIVE** → King hot |
| Accrue on real TVL | Needs depositors / seeded books |
| Optional fee bump | 10% → 12–15% only after Phase 1 cash lands (King GO) |
| Carry scripts | `CarryEthCbethBrett.s.sol` when capital exists |

### Phase 2 exit

RSS idle **or** BRETT idle ≥ ops size · fee recipient seeing non-dust accrue · both markets “alive” on Morpho explorers.

---

## PHASE 3 — Expand: capital pools · gov · scale

**Goal:** External capital sits facing Kingdom markets. Empire compounds.

### 3A — Capital pools (hunt where money already is)

| Pool class | Ask |
|------------|-----|
| Gauntlet / Steakhouse / Re7 Base USDC vaults | PA **maxIn** on RSS market (then BRETT) |
| Morpho governance / listing channels | Surface Kingdom markets as curated venues |
| Aero / Uni LPs | Seed RSS/USDC AMM **after** Phase 1 war chest (see `OPS-AMM-BOOTSTRAP.md`) |
| Desk OTC network | Recurring placement facility beyond one fill |

Packet: `CAPITAL-POOLS-PACKET.md`

### 3B — Governance opportunities

| Opportunity | Play |
|-------------|------|
| Morpho IRM/LLTV governance sets | Stay on AdaptiveCurve + approved LLTVs (already) |
| Vault curator reputation | yRSS as sovereign USDC vault — public APY page / Morpho app visibility |
| veAERO / emissions (later) | If AMM seeded — Ignition-style incentives with **treasury RSS**, not Landing bills |
| Forum / curator BD | Weekly PA maxIn asks until doors open |

### 3C — Scale ladder

1. Phase 1 $500k secure on Landing.  
2. Phase 2 both books seeded.  
3. Raise PA caps $700k → $2M → $5M as foreign maxIn opens.  
4. Desk restock from free RSS for ongoing placement.  
5. BRETT loop **only** after Morpho BRETT idle exists (chief lock stands).

### Phase 3 exit

Foreign PA maxIn &gt; 0 on RSS · Landing ops sustainable · BRETT optional cash-leg live · fee income non-dust.

---

## Scoreboard (always)

| Metric | Phase 1 win | Phase 2 win | Phase 3 win |
|--------|-------------|-------------|-------------|
| Landing USDC | **≥ $500k** | hold + buffer | growing |
| Desk raised | ≥ $500k **or** cash-leg hit | restock ready | recurring |
| RSS market idle | unlocked | ≥ $100k+ | multi-hundredk+ |
| BRETT market idle | — | &gt; $0 seeded | borrowable |
| yRSS TVL | magnet on | growing | curator-grade |
| Fee accrued | — | non-dust | ops-relevant |

```bash
cd king-pod && ./script/phase-expand-status.sh
```

---

## Doctrine

- **Both markets.** RSS pays first. BRETT expands.  
- **Phase 1 = $500k Landing** — non-negotiable before vanity seeding.  
- No flash payroll lies. No empty-book BRETT borrow cosplay.  
- Seed = put **USDC face** on Morpho books (or desk USDC in).  
- God first. Hom. King GO on live fires.

**Chief status:** Plan locked. Packets + status engine below. Fire Phase 1 guns.
