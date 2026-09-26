# FREEZE — CN Zero-Capital Recycler (fix the inefficient $9M spend)

**Mode:** FREEZE · plan law · **no flash fire · no hunt unfreeze · no KING_GO**  
**Tone:** CN desk spirit accepted. Old “park $9M cash” plan rejected. **Physics not mythology.**

---

## Scribe verdict

The King is right: **do not spend $9M hard USDC** just to spin a loop.  
The CN alternatives are the correct *instinct*. Two of three, as written, **fail live math**. One can run as **delever only** — it does **not** mint a $375M war chest.

```
Kingdom does not pay $9M to play.
Kingdom also does not pretend ΔUSDC≈0 is a war chest.
```

---

## Live facts that judge the CN plan

| Fact | Live |
|--|--|
| PARK util | **100%** · supply≈borrow **~$228.7M** |
| HOT | **Sole PARK borrower** (~$228.7M debt) |
| yRSS | Supplies the book · HOT `maxWithdraw=0` |
| HOT USDC | **1 wei** |
| Balancer Vault USDC | **~$81.7k** — **cannot** flash $9M |
| Morpho contract USDC | **~$229M** — Morpho `flashLoan` *can* size $9M |
| HuntRouter `killSwitch` | **true** (locked by law) |
| Boss / IdleTap USDC idle | **~$0** |

---

## Option 1 — Flash-Loan Recycler (“Free” Sweep)

### CN claim
Borrow $9M → repay PARK → withdraw freed → treasury → repay flash → unlock $375M float · King spends $0.

### Live identity (atomic)

```
+F flash USDC
−F Morpho.repay(PARK)          # HOT debt −F
+F yRSS.withdraw               # vault claim −F, USDC +F to HOT
−F flash repay (+ fee)
────────────────────────────
Δ HOT USDC ≈ 0 − fee
Δ PARK borrow −F
Δ yRSS TVL  −F
```

If withdraw takes the idle the repay just created, **supply and borrow both fall by F** → util stays **~100%**.  
You **delevered** the deed. You did **not** create spendable Circle. You did **not** fill SelfRepayingTreasury with net new dollars.

### Liquidity
- Balancer flash: **REJECT** for $9M (only ~$82k USDC on Base vault).
- Morpho flash: **size OK** (~$229M USDC in Morpho) — identity still nets ~0.

### Law
| | |
|--|--|
| As **war-chest / $375M unlock** | **REJECT** |
| As **optional delever** (cut debt + shrink yRSS claim, pay flash fee) | **ALLOW only under explicit King DELEVER_GO** — not Phase-2 “float unlock” |
| Fire now | **NO** |

---

## Option 2 — yRSS Collateral Swap (Internal Move)

### CN claim
Use yRSS as coll to mint temporary $9M USDC against the vault; repay from freed-float yield.

### Live
- yRSS shares are **not** posted as Morpho coll on a deep USDC book today.
- IdleTap / Boss eUSD–USDC idle ≈ **$0**.
- `maxWithdraw=0` — cannot “pull USDC from vault” without first creating idle (circular).
- No live “borrow USDC against yRSS” market with $9M fill for HOT.

### Law
**REJECT** as written. Internal move requires a **named market + idle + oracle** — none ready. Do not code a fantasy vault-loop.

---

## Option 3 — MEV Micro-Hunt (Earned Sweep)

### CN claim
Unfreeze HuntRouter bots → earn $9M USDC from arb/liquidations → fund Phase 2.

### Live
- `killSwitch=true` — hunt body blocked by prior fire law.
- Prior hunt smoke was **$1** flash path proof, not a $9M printer.
- “Limited hunt earns $9M” is **timeline mythology**, not an engineering gate.

### Law
**REJECT** as Phase-2 capital door. Hunt stays killed until King names size, EV, and risk. Not a substitute for idle physics.

---

## What “unlock $375M float” actually is

| Meaning | Honest? |
|--|--|
| Net +$9M USDC in treasury from flash peel | **False** (identity ≈0) |
| Paper / BoundLanding **capacity** from locking eUSD·gUSD | **Capacity ≠ cash** — needs Landing/HOT float + lock txs |
| Lower PARK interest forever via flash delever | **Partial** — debt down, TVL down; util may stay ~100% if withdraw matches repay |
| External USDC door (wire / 7683 / sellGem buyer) then recycler | **True cash path** — still valid, not “spend to lose”; it’s working capital |

CN spirit kept: **prefer engineering over parking $9M idle cash.**  
CN overclaim cut: **flash ≠ free war chest.**

---

## Corrected Phase-2 law (zero-capital first)

```
1) NO spend of King USDC stockpile to "buy" the loop
2) NO flash-peel marketed as +$375M cash
3) Flash delever only with DELEVER_GO (optional, fee-aware)
4) Real war chest still needs a USDC door OR honest capacity lock (eUSD)
5) Hunt stays kill-switched
6) China / NFC still Phase 4
```

### Ordered doors (CN-aligned)

| Priority | Door | Spend King USDC? |
|--|--|--|
| A | **7683 / LitePSM inbound** — counterparty brings USDC; credit idle grows | No (they pay) |
| B | **IdleTap** when a USDC book has idle **and** HOT has coll | No stockpile |
| C | **BoundLanding lock** of kingdom eUSD for capacity optics | No USDC |
| D | **Flash delever** (Morpho flash) — shrink deed only | Fee only |
| E | OTC wire | External |

---

## Freeze rules

1. **No fire** of flash recycler / hunt unfreeze / yRSS self-borrow until King names door **A–D** with size.  
2. Update supersedes “must park $9M HOT cash” as the *only* story — cash park is **optional working capital**, not dogma.  
3. Scripts: `FireRecyclerLoopCast.sh` remains gated on real USDC (honest cash path). Flash delever = separate future script under `DELEVER_GO`.  
4. HOT key: keep for chosen door · rotate after that fire.

---

## One-block

```
FREEZE=cn-zero-capital-recycler
REJECT flash-as-war-chest (ΔUSDC≈0−fee · util may stay 100%)
REJECT yRSS self-mint USDC (no market/idle)
REJECT hunt earns $9M (killSwitch=true)
ACCEPT CN spirit: no King USDC stockpile tax
DOORS=7683/PSM inbound · IdleTap+coll · eUSD capacity lock · optional flash delever
NO China · NO fire until King names door
```

---

## Cross-refs

- Prior cash-gate freeze: `FREEZE-PHASE2-RECYCLER-LOOP.md`  
- Sequence: `FREEZE-SECURE-BEFORE-CHINA.md`  
- Flash peel audit (same identity): `FREEZE-16Z-NO-BOSS-USDC-AUDIT.md`  
- Phase-1 done: `FIRE-HARD-LOCKS-ZK-RAILS.md`
