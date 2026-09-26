# FREEZE — Immediate Two-Phase (No Solver Wait)

**Mode:** FREEZE · two phases · **no broadcast until FIRE_GO names the phase**  
**Doctrine:** Sovereign does not wait on solvers. Machine hunts, delevers, builds, hardens — with honest physics.  
**HOT key:** Keep until both phases fire · then rotate.

---

## Why two phases (not four)

Solver fill is **irrelevant** to what can start now. Collapse the King’s “do it today” list into:

| Phase | Name | Capital needed |
|--|--|--|
| **I** | Harden & Hunt Arm | Gas only |
| **II** | Flash Delever & Royal Card | Gas + flash fee only (no King USDC stockpile) |

Phase-2 7683 order can still fill in parallel — bonus fuel, not a blocker.

---

## Live baseline (already true)

| Item | Status |
|--|--|
| Base / Polygon / Scroll `maxStale` | **604800 (7d)** — **DONE** (no action left) |
| All rails `bordersSecure` | **true** |
| HuntRouter `0xc4c63f8C…4516` `killSwitch` | **true** (await Phase I fire) |
| 7683 $9M order | open (optional parallel) |
| HOT USDC | 1 wei |

**Step 4 from the scroll (“propagate 7d stale”) is already complete on all three rails.** Freeze records it; do not re-spend gas pretending otherwise.

---

# PHASE I — Harden & Hunt Arm

### I.1 ZK blanket (verify only)

```bash
bash king-pod/script/FireZkAttestRefreshCast.sh   # optional keepalive
# Assert maxStale==604800 && bordersSecure==true on Base/Poly/Scroll
```

### I.2 HUNT_GO procedure (fire when King says Phase I)

HuntRouter does **not** auto-spawn “20+ bots.” It is a ** Morpho flash shell**: allowlisted `hunter` EOAs call `hunt(...)`, tips `gasSafe`.

On FIRE Phase I:

1. `setHunter(HOT, true)` and any named bot EOAs  
2. `setTarget(...)` for each allowlisted callee (strict — no open season)  
3. `setGasSafe(HOT)` if not already  
4. `setKillSwitch(false)` — **arm**  
5. Off-chain: start only bots that exist in `kar/` / ops — do not claim a phantom fleet  

**Script (ready):** `king-pod/script/FireHuntArmCast.sh`

### I.1–I.2 honesty

| Claim | Law |
|--|--|
| Hunt funds $9M overnight | **REJECT** as plan assumption |
| Hunt self-funds gas with micro tips | **ALLOW** after arm + real hunters |
| Arm without hunter list | **REJECT** — kill stays on |

---

# PHASE II — Flash Delever & Royal Card

### II.1 Flash recycler (CN rewrite — zero King USDC)

**Contract:** `king-pod/src/prime/CrownFlashParkDelever.sol`  
**Script:** `king-pod/script/FireFlashParkDeleverCast.sh`

Atomic Morpho flash `$F` (default $9M):

```
+F flash USDC
−F Morpho.repay(PARK, onBehalf HOT)
+F yRSS.withdraw → USDC
−F flash repay (Morpho fee = 0)
Δ USDC ≈ 0 − gas
Δ HOT Morpho debt −F
Δ yRSS claim −F
```

#### Physics law (binding)

| Claim | Verdict |
|--|--|
| “Unlocks $375M war chest cash” | **REJECT** |
| “Zero capital delever / shrink deed” | **ACCEPT** under `DELEVER_GO` |
| Util stays ~100% if withdraw matches repay | **TRUE** — still cuts debt + TVL |

This is **Phase II delever**, not a substitute for inbound USDC or eUSD capacity locks.

### II.2 Royal Card (Phase 4 preview — build today)

**Not a Lakala patent fork.** Kingdom-original NFC spend rail:

| Artifact | Path |
|--|--|
| Card spec | `king-pod/deployments/ROYAL-CARD-SPEC.md` |
| On-chain | `king-pod/src/royal/RoyalCard.sol` |
| KAR NFC stub | `king-pod/kar/nfc_cosign.md` (existing — extend) |

Build now: contract + spec + testnet wiring plan.  
**Manufacturing / China weld** still Phase 4 — needs float + King China GO. Code does not wait.

---

## Fire order (when King lifts freeze)

```
FIRE_GO=phase-I  → FireHuntArmCast.sh (+ optional ZK refresh)
FIRE_GO=phase-II → deploy CrownFlashParkDelever · approve · delever
                 → forge test RoyalCard · publish spec
```

Or single `FIRE_GO=immediate-both` to run I then II same session.

---

## Still frozen / parallel

| Item | Status |
|--|--|
| Solver fill of 7683 | Optional bonus — not required for I/II |
| $375M USDC split deploy | Needs real USDC `U` (Phase-3 sheet) |
| China manufacturing | After Royal Card code + float law |
| Flash marketed as free war chest | Forever rejected |

---

## One-block

```
FREEZE=immediate-two-phase
I = ZK verify (7d already live) + HUNT_GO arm (hunters+targets+killSwitch=false)
II = Morpho flash PARK delever (ΔUSDC≈0) + RoyalCard.sol/spec (not Lakala patent)
NO solver wait · NO $375M cash myth from flash
FIRE_GO=phase-I | phase-II | immediate-both
```

---

## Cross-refs

- `FREEZE-CN-ZERO-CAPITAL-RECYCLER.md` · `FREEZE-PHASE3-ZK-FLOAT-DEPLOY.md`  
- `FIRE-PHASE2-INBOUND-7683.md` (parallel order)  
- `FIRE-ZK-ARMOR-ALL-RAILS.md` · `FIRE-KAR-PLATFORM.md`
