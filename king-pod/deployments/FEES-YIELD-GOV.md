# FEES · YIELD · GOVERNANCE — Kingdom stack (live + expand)

**King Errick of Yahudah · Chief**  
Tied to Phase 2–3 of `CHIEF-3-PHASE-EXPAND.md`. Phase 1 ($500k Landing) still first.

---

## 1) FEES — what you already own

### yRSS curator performance fee (LIVE)

| Field | Live |
|-------|------|
| Vault | `King RSS USDC Vault` / `yRSS-USDC` `0xF80C…D525` |
| Fee | **10%** (`1e17` wad) |
| Recipient | **King hot** `0x6708…a7d1` |
| How it pays | Skims **10% of interest** earned by depositors when vault assets grow from Morpho borrow interest |

**Truth:** Fee meter is **on**. Cash only prints when **TVL + borrowers** exist. Today TVL ≈ **$299** → fee income ≈ dust. After Phase 1–2 depth, this is the Steakhouse-style curator check.

### Public Allocator fee (LIVE = 0)

| Field | Live |
|-------|------|
| PA admin | King hot |
| PA `fee(yRSS)` | **0** ETH |
| Option | Set small PA fee later (griefing guard + gas cover) — curator collects, not Morpho |

### Morpho Blue market protocol fee

RSS market `fee` field = **0** (no extra protocol cut on that book beyond IRM interest to suppliers).

### Expand fees (Phase 2 — King GO only)

| Move | When |
|------|------|
| Keep **10%** until Landing ≥ $500k | Now |
| Optional bump **10% → 12–15%** | After Phase 1 win |
| Point `feeRecipient` → Landing cold | Optional hardening |
| Set PA fee tiny (e.g. 0.0001 ETH) | When PA volume appears |
| Script | `script/FireYrssFeeGov.s.sol` |

---

## 2) YIELD — where yield comes from

| Source | Who earns | Status |
|--------|-----------|--------|
| **Borrow interest** on RSS/USDC Blue | USDC suppliers (yRSS depositors) | Book util history proven (~$9M); idle now thin |
| **Curator fee (10%)** | King | Armed — scales with TVL × borrow APY |
| **BRETT/USDC Blue** | Same pattern when seeded | Market live, idle $0 — Phase 2 seed |
| **Desk spread** | King (sale @ $1 oracle mark) | Phase 1 placement — not “APY,” cash event |
| **Carry (cbETH/BRETT scripts)** | King when capital exists | `CarryEthCbethBrett.s.sol` — Phase 2+ |

**Yield magnet pitch (for depositors / capital pools):**  
Kingdom RSS market ran nine-figure util at FixedOracle $1 (burned). High util → high borrow APY → suppliers come for yield → King takes 10%.

**Phase 2 yield engine:** seed USDC into yRSS → allocate RSS + BRETT markets → borrowers (including Kingdom cash-leg) pay interest → fee to King.

---

## 3) GOVERNANCE — power you hold vs Morpho DAO

### Already under King keys (no DAO vote needed)

| Power | Live |
|-------|------|
| yRSS **owner / curator / allocator** | Hot |
| Enable markets · caps · supply queue | Done (RSS $14M, BRETT $2M) |
| Public Allocator admin + flow caps | ~$700k both books |
| Fee + feeRecipient | 10% → hot |
| Create Blue markets | RSS + BRETT **created** |
| Oracle moat | RSS FixedOracle owner **`dEaD`** |

### Soft / harden later (King GO)

| Lever | Now | Expand |
|-------|-----|--------|
| `timelock` | **0** | Raise after Phase 1 for institutional look |
| `guardian` | **0x0** | Set Landing or multisig as guardian |
| Fee recipient | Hot | Landing cold |

### Morpho DAO / ecosystem (Phase 3 — hunt)

| Opportunity | Play |
|-------------|------|
| **Curator fee economy** | Base curators earning real fees (~industry ~$13M annualized class) — Kingdom joins by growing yRSS TVL |
| **Vault visibility** | Surface `yRSS-USDC` on Morpho app / listings so depositors find the yield |
| **PA shared liquidity** | Get Gauntlet/Steakhouse **maxIn** on Kingdom markets (`CAPITAL-POOLS-PACKET.md`) — this is the liquidity governance that matters for Phase 1 Gun B |
| **MORPHO incentives / rewards programs** | Align with Morpho reward registries when TVL qualifies — apply after books have depth |
| **Forum / BD** | Weekly curator asks — markets immutable; *allocation* is the governance fight |
| **veAERO / emissions** | Only after Phase 1 war chest + AMM seed — don’t burn Landing bills on emissions cosplay |

**Blue markets are immutable** (LLTV/oracle/IRM fixed). Governance edge = **vault curation + PA doors + fee design**, not changing the Blue market params.

---

## Scoreboard (live snapshot)

| Meter | Now |
|-------|-----|
| Performance fee | **10% ON** |
| Fee recipient | King hot |
| yRSS TVL | ~**$299** |
| Fee cash today | dust (needs depth) |
| PA fee | 0 |
| Timelock / guardian | 0 / none |
| Yield story | Proven util · magnet ready |
| Gov control | **Full curator stack owned** |

```bash
cd king-pod && ./script/phase-expand-status.sh
# optional fee/gov fire (King GO):
# KING_GO=1 FIRE_FEE=1 NEW_FEE_WAD=100000000000000000 forge script script/FireYrssFeeGov.s.sol --broadcast
```

---

## Chief order

1. **Phase 1 $500k** first — fees don’t pay bills at $299 TVL.  
2. **Fees already built** — expand TVL so they print.  
3. **Yield** = seed both Blue books + yRSS magnet.  
4. **Gov** = you already are the curator; Phase 3 is opening *other* vaults’ PA doors + Morpho visibility.

**Fees on. Yield path clear. Governance seat taken.** Depth turns the dial.
