# Three-phase plan — adjust sheet (Morpho ELE loan)

**Source of truth:** `KING-SETUP.md` — Morpho ELE/USDC + ZK pack → Landing. Not yRSS.

---

## Live readiness (Phase 1)

| Meter | Live |
|--|--:|
| Morpho ELE/USDC idle | **≈ $0** |
| Morpho ELE coll (hot) | ~630.8k → room @77% ≈ **$486k** only |
| Free ELE (Landing+hot) | ~76.6M → room **if posted** ≈ **$59M** |
| CDP HF | ≈ **1.55** |
| Can borrow $13M today? | **No** — idle = 0; also need more ELE posted for $13M room |

**GO Phase 1 only when:** idle USDC ≥ ask **and** Morpho coll room ≥ ask **and** King `LIVE_ARMED`.

---

## Adjust Phase 1 (loan)

| Plan item | Adjust |
|--|--|
| Borrow $13M USDC | Keep as **target size**. Blocked until **idle** exists (Blue supply / PA / seed). Post enough ELE first (room today on posted coll only ~$486k). |
| HF ≥ 1.55 | CDP HF is ~1.55 now. Morpho uses **LLTV/LTV**, not CDP HF — track Morpho LTV buffer separately (e.g. stay under ~70% of LLTV). |
| 50/50 Spend / Earn vault·loop | **Cut the Earn-half vault/loop.** That is the old yELE recycle. Doctrine: **100% of borrowed USDC → Landing KEEP** (bills/ops). Passive is fees/skims **into** Landing — not recycling the loan. |
| Activate fees on all markets | Morpho Blue markets don’t take vault fees. Do: **yELE fee → Landing** at GO; yRSS already 10%→Landing. Optional Merkl later. |

**Phase 1 rewritten:** seed/open idle → post ELE for room → `borrow($13M)` → **Landing KEEP 100%** → ZK pack on actions → pre self-liq armed.

---

## Adjust Phase 2 (depth)

| Plan item | Adjust |
|--|--|
| Flash seed ELE/WETH & ELE/cbBTC | Markets **already exist** and are **already self-looped** (~10 WETH / ~0.5 cbBTC util≈100%). More flash loops ≠ spendable cash. Prefer **external idle** or owned seed into **ELE/USDC** (the USDC loan market). |
| Internal loops compounding | Only if they don’t lock KEEP. No supply of Landing USDC back into same market/vault. |
| Sweep fees to KingVault | Use **Landing** as ops wallet (already fee sink for yRSS). |

---

## Adjust Phase 3 (expand)

| Plan item | Adjust |
|--|--|
| Add WETH/cbBTC as collateral | Clarify: (A) Elepan→borrow WETH/cbBTC markets already live; or (B) WETH/cbBTC→borrow USDC needs blue-chip coll King barely holds. Don’t conflate. |
| Multi-market seeding + ZK advances | ZK credit pool is **$0** until a supplier. Pack gate is already proven. Seed ≠ ZK mint. |
| Perpetual HF/oracle | Keep fixed ELE oracle discipline; don’t lever past safe buffer. |

---

## Add (missing from plan)

1. **Idle prerequisite** before any $13M `borrow`.  
2. **Landing KEEP 100%** — no 50% vault recycle.  
3. **Coll post plan** (Landing ELE → hot → Morpho) before size.  
4. **Pre self-liq** armed before size-up.  
5. **No live fire** without King GO / `LIVE_ARMED`.

---

## Verdict

Phase order (loan first) is fine.  
**Must change:** kill 50/50 earn-loop; fix idle+coll math; treat WETH/cbBTC loops as already-there, not Phase-2 magic; fees = vault→Landing, not “all Morpho markets.”
