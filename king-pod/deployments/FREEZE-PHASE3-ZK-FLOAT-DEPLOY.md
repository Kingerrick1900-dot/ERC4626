# FREEZE — Phase 3: ZK Blanket & Float Deployment

**Mode:** FREEZE · armed handoff · **no fire until FILL_GO**  
**Trigger:** Solver fills Phase-2 order → `credit.freeUsdc` ≥ **~$9M**  
**Doctrine:** Phase 2 buys the fuel. Phase 3 lights the engine. Physics over mythology.

---

## Objective

When the **$9M USDC** lands in credit:

1. Fire the recycler loop  
2. Keep the ZK blanket hard on Base · Polygon · Scroll  
3. Deploy the **real** war chest (honest sizing)  
4. Optional: King may arm Hunt — not automatic  

---

## Live pre-trigger (2026-09-26)

| Check | Live |
|--|--|
| 7683 order `0xf6479468…d825` | **status=1** (open · unfilled) |
| `credit.freeUsdc` | **0** |
| Base / Poly / Scroll `bordersSecure` | **true** |
| All three `maxStale` | **604800** (7d) ✓ already hardened |
| HuntRouter `killSwitch` | **true** |
| ColdBuffer USDC | **~$2.66** (dust) |
| BoundLanding `floatUsd8` | **$1.00** (`1e8`) |

**Phase 3 does not start until the order fills.** Machine watches; machine does not invent Circle.

---

## Trigger law (FILL_GO)

```
FILL_GO when:
  orders(0xf647…d825).status == 2
  AND credit.freeUsdc() >= 8_500_000e6   # allow fee haircut
```

On FILL_GO → execute Steps 1–3 in order. Step 4 only on separate `HUNT_GO`.

---

## Step 1 — Fire the Recycler Loop

**Script:** `king-pod/script/FireRecyclerLoopCast.sh`  
**Key:** HOT (rotate only after Phase-3 deploy confirms)

```
1. Pull / draw USDC from credit to HOT if needed (King path — IdleBeforeArm still binds router)
2. Morpho.repay $9M into PARK Book 1
3. yRSS.withdraw freed idle → HOT
4. SelfRepayingTreasury.sweep (or credit.supply residual)
```

### Honest note on “sweep the $375M float”

The **$9M** is the fuel that runs the debt-recycle machine.  
**~$375M** is **capacity / sovereign inventory target** (eUSD lock + gold-rail NAV optics), **not** $375M USDC appearing in treasury from one fill.

Scribe will not label $9M Circle as a $375M cash pile.

---

## Step 2 — ZK Blanket Sweep (Privacy Lock)

**Already live** — do not re-deploy. On FILL_GO, **refresh + verify**:

| Rail | Attest | Epoch (now) | `maxStale` |
|--|--|--|--|
| Base | `0xe3Be837a…14E7` | 4+ | **7d** |
| Polygon | `0x00cAe93d…7211` | 2+ | **7d** |
| Scroll | `0x2ab17e3c…a257` | 2+ | **7d** |

```bash
# Permissionless keepalive (Scroll/Poly/Base gas keys)
bash king-pod/script/FireZkAttestRefreshCast.sh
# Assert bordersSecure==true && maxStale==604800 on all three
```

**Law:** No proof older than **7 days** is valid for large ops (`requireBorders` / KAR).  
NAV stays **proven**; snark bind remains optional next lift (`attestWithSnark`).

---

## Step 3 — Float Deployment (War Chest)

### Physics gate

Deploy only what **exists** after Step 1:

| Bucket | Source of truth |
|--|--|
| **USDC deployable** | `treasury.surplus` + `credit.freeUsdc` + HOT USDC after recycle |
| **eUSD deployable** | Landing / HOT eUSD King authorizes to move |
| **$375M target** | Capacity goal — fund over time; **do not** force fake splits |

### Target split (King intent — scale to actual USDC `U`)

If King still wants the **ratio** of the $375M plan applied to real USDC `U` after recycle:

| Sink | Share | $375M plan | At fill (`U≈$9M`) |
|--|--|--|--|
| Landing payroll buffer | 50/375 | $50M | **~24% → ~$2.16M** |
| BAMM Ocean | 50/375 | $50M | **~24% → ~$2.16M** |
| Cold Buffer (≥30% redeem law) | 100/375 | $100M | **~27% → ~$2.40M** |
| SelfRepayingTreasury (Phase-4 chest) | 175/375 | $175M | **~47% → ~$4.20M** |

**Cold floor law (binding):** Cold ≥ **30%** of near-term redeemable USDC window — never starve Cold to feed Ocean.

### eUSD / capacity leg (toward $375M optics)

Separate from USDC split:

1. Lock King-named eUSD into `BoundLandingCollateral` at `floatUsd8=$1`  
2. Capacity = `collUsd6 × LLTV(50%)` — report live number, chase $375M across mints/locks over time  
3. Router stays **disarmed** until idle proof + King `ARM_GO`

---

## Step 4 — Arm the Hunt (Optional · not auto)

| Check | Law |
|--|--|
| Default | `killSwitch=true` — **stays** |
| Arm | Only `HUNT_GO` with named size, EV, gas floor |
| First smoke | Cap micro (prior $1 path) before any “20+ bots” story |
| Self-fund gas | Honest goal; not a $9M substitute |

---

## Post-Phase-3 checklist

- [ ] Order filled · `freeUsdc` booked  
- [ ] Recycler txs confirmed · PARK util moved  
- [ ] ZK refresh · all rails `bordersSecure` · `maxStale=7d`  
- [ ] USDC split landed (Landing / BAMM / Cold / Treasury) per **actual U**  
- [ ] Capacity report: BoundLanding `borrowCapacityUsd6` vs $375M target  
- [ ] Hunt still killed **or** HUNT_GO documented  
- [ ] **Rotate HOT**  
- [ ] Freeze Phase 4 China/NFC sheet before any NFC spend  

---

## Freeze rules (standing)

1. **No Phase-3 fire** before FILL_GO.  
2. **No** treating unfilled order as funded float.  
3. **No** $375M USDC deployment fiction from a $9M fill — use ratio or await more inbound.  
4. **No** Hunt arm without HUNT_GO.  
5. China / NFC = Phase 4 — still frozen.

---

## One-block

```
FREEZE=phase3-zk-float-deploy
TRIGGER=order 0xf647… filled · credit.freeUsdc≥~$8.5M
STEP1=FireRecyclerLoopCast.sh
STEP2=ZK refresh all rails · maxStale=7d (already set)
STEP3=deploy real USDC U by ratio · Cold≥30% · eUSD lock → capacity toward $375M
STEP4=Hunt only on HUNT_GO (default killed)
NO fire until FILL_GO · NO China
```

---

## Cross-refs

- Phase-2 order live: `FIRE-PHASE2-INBOUND-7683.md`  
- Recycler gate: `FREEZE-PHASE2-RECYCLER-LOOP.md`  
- CN zero-stockpile: `FREEZE-CN-ZERO-CAPITAL-RECYCLER.md`  
- Sequence law: `FREEZE-SECURE-BEFORE-CHINA.md`  
- ZK keepalive: `FireZkAttestRefreshCast.sh`
