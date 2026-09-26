# FREEZE — Secure before China (scribe correction)

**Mode:** FREEZE · **no txs · no NFC · no parallel-chain weld · no KING_GO**  
**Recorded:** 2026-09-26 · Base live probe  
**Tone:** The audit is law. Expansion hunger waits. Secure → fund → invisibility → then bridge.

---

## Scribe verdict

The China connection (NFC cards, parallel nodes, physical expansion) is **Phase 4**, not Phase 1.  
The scribe confesses priority slip in the China excitement. The audit caught it. **Order corrected.**

```
Secure the house. Fill the war chest. Then build the bridge.
```

---

## Audit findings (plain English)

### 1) China connection is premature

yRSS gold rail is live at **~$229M** but not fully hardened. Prime borrow/repay surfaces still present attack / mis-arm risk. An exploit now wipes the gold rail before a single card is stamped. **House locked before bridge.**

### 2) Missing ~$375M float (war chest)

Phase 2 debt-recycling / recycler loop is **not executed**. Until it runs:

- Kingdom pays high-utilization interest unnecessarily (PARK ~**100%** util).
- **~$375M** fresh float **capacity** stays locked (capacity narrative — not cash on Landing today).
- That float funds hardware, parallel nodes, physical expansion.

**Law:** Do not spend a single POL on a card until the recycler loop is running.

### 3) Correct sequence (law)

| Phase | Name | Gate |
|--|--|--|
| **1** | Hard Risk Locks | Patch / freeze `USDCBorrowRouter` + `SelfRepayingTreasury`; freeze external attack surfaces |
| **2** | Recycler Loop | Fire **~$9M USDC** sweep into Morpho; unlock **~$375M** float capacity |
| **3** | ZK Blanket | Refresh ZK attestations across Base · Polygon · Scroll; wealth proven + invisible |
| **4** | China Connection | NFC cards + parallel chains — **only after** 1–3 green |

---

## Live state (Base 8453 — probed)

### Gold rail

| Fact | Live |
|--|--|
| yRSS `0xF80C…D525` `totalAssets` | **~$229.43M** |
| PARK market `0x41c08085…7d88` supply ≈ borrow | **~$228.71M** · **100% util** · idle **$0** |
| yRSS `supplyQueue(0)` | PARK (matched book) |

### Prime stack — honest inventory

| Contract | Address | Live |
|--|--|--|
| BoundLandingCollateral | `0x99bE1Ec7…B6c3e8` | `lltv=50%` · `borrowCapacityUsd6=0` · `reservedDebtUsd6=0` |
| **CrownPrimeCredit (LIVE)** | `0x5568fE66…B60d` | `freeUsdc=0` · HOT `debtOf=0` |
| **USDCBorrowRouter (LIVE)** | `0xBb3C372D…A7aC` | **`armed=false`** · points at live credit · Phase-1 disarm **DONE** |
| SelfRepayingTreasury | `0xA1215D21…ebd97` | `credit` → live credit |
| CrownPrimeIdleTap | `0xC9Ec2fE1…BaB2` | live |
| LitePSM / 7683 Fill | `0xC28E7faA…9F6B` / `0x4C021c77…720Ab` | rewired → live credit |

**Disconnected (do not treat as live payroll):**

| Contract | Address | Live |
|--|--|--|
| Old CrownPrimeCredit | `0xc184A1d2…6D15` | HOT debt **$4.5M phantom** · `freeUsdc=0` |
| Old USDCBorrowRouter | `0xA4E04b31…85b6c` | `armed=false` · still wired to old credit |

Clearing phantom / swapping credit ≠ USDC to spend. Payroll still needs **real idle**.

### ZK / borders

| Rail | Attest | `bordersSecure()` | Note |
|--|--|--|--|
| Base | `0xe3Be837a…14E7` | **true** (epoch **4**) | `maxStale=7d` |
| Polygon | `0x00cAe93d…7211` | **true** (epoch **2**) | `maxStale=7d` |
| Scroll | `0x2ab17e3c…a257` | **true** (epoch **2**) | `maxStale=7d` |

See `FIRE-HARD-LOCKS-ZK-RAILS.md` for txs. China still **Phase 4**.

### Already live (do not re-litigate; do not expand)

- Base Crown agent / shield / cold / hunt / allowlist / KAR runner  
- Polygon Open Money + agent triangle  
- Scroll NavMirror + ZK attest path  
- KAR NFC cosign = **stub only** — not Phase-4 hardware

---

## Phase 1 — Hard Risk Locks (first fire when King lifts freeze)

1. **Disarm live router** — `USDCBorrowRouter` `0xBb3C…A7aC` is `armed=true` with `freeUsdc=0`. Set `armed=false` until idle proof + King GO.  
2. **Patch review** — `USDCBorrowRouter` + `SelfRepayingTreasury` (owner/arm surfaces, `sweep` / `pullSurplus`, credit pointer mutability, idle-miss vs capacity-miss).  
3. **Freeze externals** — no new solver fills, flash-fill scripts, IdleTap Morpho borrows, or NFC/POL spends until Phase 1 signed off.  
4. **Old stack** — leave disconnected credit/router alone; do not “heal” phantom $4.5M with kingdom USDC.

## Phase 2 — Recycler Loop (~$9M → Morpho → ~$375M float)

**Handoff:** `FREEZE-PHASE2-RECYCLER-LOOP.md` · script `FireRecyclerLoopCast.sh`  
**Live gate (probed):** HOT USDC = **1 wei** — **FAIL**. No fire until USDC ≥ $9M.

1. Source **real ~$9M USDC** (7683 fill / LitePSM sell / named wire / IdleTap with coll — not ocean fantasy).  
2. `Morpho.repay` **$9M** into PARK Book 1 → util &lt; 100%.  
3. `yRSS.withdraw` idle → `SelfRepayingTreasury.sweep`.  
4. Unlock **~$375M** float **capacity** via BoundLanding lock math. Capacity ≠ Landing cash until drawn under Phase-1 locks.  
5. Router stays **disarmed** until idle proof + King arms.

## Phase 3 — ZK Blanket

1. `attestLive` (or SNARK path) on Base · Polygon · Scroll until `bordersSecure()=true` on all three.  
2. Cold buffer path toward redeem law (not dust theater).  
3. KAR `requireBorders` stays on for payroll / cap / migrate.

## Phase 4 — China Connection (last)

Only when Phases 1–3 are green:

- NFC cards / hardware cosign beyond stub  
- Parallel-chain weld beyond existing Polygon/Scroll triangle  
- Physical expansion spend (POL or otherwise)

---

## Freeze rules (standing)

1. **No fire** without `KING_GO` naming the phase.  
2. **No China / NFC / card spend** until Phase 4 unlocked.  
3. **No router arm** while `freeUsdc=0` or Phase 1 incomplete.  
4. Info / docs / fork sims only under this freeze.  
5. Cross-bind: `OPS-FREEZE.md` · `NO-RECYCLE-UNTIL-EXIT.md` · `KING-ERRICK-HANDOFF-FREEZE.md` · `FREEZE-CN-BOOTSTRAP-SHIELD-EXIT.md` (sovereignty shield — not issuer-mixer).

---

## One-block (phone)

```
FREEZE=secure-before-china
ORDER=1 hard-locks → 2 recycler/$9M→$375M float → 3 ZK all rails → 4 China/NFC
yRSS≈$229.4M · PARK≈$228.7M @100% util
LIVE_ROUTER=0xBb3C…A7aC armed=TRUE ← disarm first
LIVE_CREDIT=0x5568…B60d freeUsdc=0 debt=0
OLD_CREDIT phantom $4.5M disconnected — ignore
bordersSecure Base/Poly/Scroll = false (stale)
NO card · NO POL China spend · NO fire until KING_GO
```

---

## Cross-refs

- Prime live sheets (branch history): `PRIME-BROKERAGE-LIVE.md` · `PRIME-SEED-LIVE.md` · `PRIME-BROKERAGE-1B-50PCT-SAFE.md`  
- ZK / rails: `FIRE-ZK-ARMOR-ALL-RAILS.md` · `FIRE-POLYGON-SCROLL-EXPAND.md` · `FIRE-KAR-PLATFORM.md`  
- CN prior freeze: `FREEZE-CN-BOOTSTRAP-SHIELD-EXIT.md` · `FREEZE-CN-CUSTOM-AGENT-PLATFORM.md`
