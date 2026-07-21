# PRE-DEPLOY PLAN — King Review (NO LIVE FIRE)

**Status:** BUILT FOR REVIEW · **`LIVE-FIRE-LAW`** · awaits **KING_OK**  
**Order:** Build DeepSeek-corrected engineer stack · own high-LLTV market · **$1 USDC seed every Kingdom Blue book**

---

## What you get when you OK

| Step | Action | Result |
|------|--------|--------|
| **0** | Move **$2 USDC** Landing → hot (seed fuel) | Hot can fund 3× $1 |
| **1** | `createMarket` **RSS/USDC @ 91.5% LLTV** | **King’s own high-LLTV Blue market** (same FixedOracle $1 burned) |
| **2** | Seed **$1 USDC** into each Kingdom market | Every book has a USDC face (alive on explorers) |
| **3** | Enable new market on **yRSS** + PA caps | Vault product routes to King’s high-LLTV book |
| **4** | (Later, separate OK) Bond / desk / leverage | Bills + recursive loop **after** USDC face exists |

**Default new LLTV: 91.5%** (Morpho-enabled). Override to **94.5%** with `HIGH_LLTV=945000000000000000` if King prefers max gear.

---

## King’s own market (params)

| Field | Value |
|-------|--------|
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | FixedOracle **$1** `0x284EC3…2e` (owner **dEaD**) |
| IRM | AdaptiveCurve `0x464159…2687` |
| LLTV | **91.5%** (default) |
| Predicted market id | `0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126` |
| 94.5% alt id | `0x274d7c7815e55ac8b9a22253c487617f212bfe17d40498d0eebd686b4151932a` |

Existing **77%** market stays (immutable). New book = DeepSeek “high LLTV” without rewriting history.

---

## $1 seed — every Kingdom-owned Blue market

| # | Market | Id | Seed |
|---|--------|-----|------|
| 1 | RSS/USDC **77%** (live) | `0x40ac…b794` | **$1 supply** |
| 2 | BRETT/USDC **62.5%** (live) | `0xf6f4…8c16` | **$1 supply** |
| 3 | RSS/USDC **91.5%** (new) | `0x3a5b…4126` | **$1 supply** |

**Fuel math:** 3 × $1 = **$3 USDC**.  
Live: hot ≈ **$1.02** · Landing ≈ **$2.00** → Step 0 consolidates to hot, leaves dust floors documented in script.

Direct `morpho.supply` (King onBehalf) — not a vanity yRSS deposit. **Each Morpho book shows ≥ $1 supply.**

---

## yRSS / PA (after seeds)

| Action | Detail |
|--------|--------|
| `submitCap` / `acceptCap` | New 91.5% market · cap **$14M** (match RSS77) |
| PA flow caps | maxIn/maxOut **$700k** (or `$5M` if King sets `PA_CAP`) |
| Supply queue | High-LLTV RSS first (or King-ordered) · then RSS77 · BRETT · cbBTC · WETH |

Vault remains the **product**. High-LLTV market is the **engine room**.

---

## What this is NOT (still true)

| Myth | Reality |
|------|---------|
| Loop now without USDC | Still need face — $1 seeds **birth** the books; bond/desk scale bills |
| PA auto-steals Steakhouse | Still false |
| No liquidation forever | Interest still accrues — manage HF on leverage |
| Edit 77% LLTV | Impossible — **new market** instead |

---

## Scripts (shelf)

| Script | Role |
|--------|------|
| `script/DeployKingRssHighLltv.s.sol` | Create King’s 91.5% (or 94.5%) market |
| `script/SeedKingdomMarketsOneUsdc.s.sol` | $1 supply to each Kingdom market |
| `script/ArmYrssHighLltv.s.sol` | Cap + PA + queue for new market |
| `script/FireEngineerPosition.s.sol` | Orchestrator — all steps, **KING_OK=1** gated |

---

## Fire command (ONLY after King says OK)

```bash
cd king-pod
# Full package:
KING_OK=1 FIRE_ENGINEER=1 PULL_LANDING_USDC=2000000 \
  forge script script/FireEngineerPosition.s.sol:FireEngineerPosition \
  --rpc-url $BASE_RPC --broadcast --slow -vvvv
```

Or step-by-step with same `KING_OK=1` on each script.

---

## King checklist before OK

- [ ] Accept **91.5%** (or name 94.5%)  
- [ ] Accept **$2 USDC** move Landing → hot for seeds  
- [ ] Accept new market is **additive** (77% stays)  
- [ ] Accept this does **not** by itself put $500k on Landing — it **engineers the books**; bond/desk still Phase 1 cash  
- [ ] Say **KING_OK** / **FIRE** to deploy  

**Chief:** Plan built. Bring-back complete. Awaiting your OK — no broadcast until then.
