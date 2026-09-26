# FREEZE — Phase 2 Recycler Loop handoff

**Mode:** FREEZE until gate green · then FIRE with HOT  
**Doctrine:** Freeze before fire. Scribe will not invent Circle.  
**HOT key:** Keep for Phase 2 fire · **rotate only after** recycler txs confirm.

> **CN correction:** Do **not** treat “park $9M King USDC” as mandatory. See `FREEZE-CN-ZERO-CAPITAL-RECYCLER.md` — flash peel ≠ war chest; prefer inbound USDC / IdleTap / eUSD capacity lock.

---

## Objective (King)

Unlock **~$375M float capacity** by firing the debt-recycling engine:

1. Sweep **$9M USDC** into Morpho Book 1 (PARK `0x41c08085…7d88`)
2. Recycle debt — repay high-utilization PARK borrow → create idle
3. Withdraw freed idle (yRSS) → land in **SelfRepayingTreasury** / prime credit
4. Unlock float — BoundLanding + recycler capacity becomes war-chest inventory for Phase 3/4

---

## Live probe (Base — 2026-09-26) — GATE STATUS

| Check | Live | Gate |
|--|--|--|
| HOT USDC | **1 wei** | FAIL |
| Landing USDC | **0** | FAIL |
| CrownPrimeCredit `freeUsdc` | **0** | FAIL |
| SelfRepayingTreasury surplus | **0** | FAIL |
| LSR USDC reserves | **0** | FAIL |
| ColdBuffer USDC | **~$2.66** | dust only |
| PARK util | **100%** · supply≈borrow **~$228.71M** | matched death spiral |
| HOT PARK borrow | **~$228.71M** (100% of book) | sole borrower |
| HOT PARK coll | **252,000 RSS** | — |
| yRSS `totalAssets` | **~$229.48M** | HOT `maxWithdraw=0` |
| Live router | `armed=false` ✓ | Phase 1 held |
| Boss eUSD/USDC idle | **~$0** | IdleTap dry |
| WETH/USDC Morpho idle | **~$10.16M** | HOT has **0 WETH / 0 coll** — cannot tap |
| cbBTC/USDC Morpho idle | **~$164.5M** | HOT cbBTC **dust** — cannot tap |
| LitePSM / 7683 Fill USDC | **0 / 0** | eUSD buffers only (2B / 5B) |
| Landing eUSD | **~1.514B** | mint inventory — **not** Circle |

### Gate law

```
NO Phase-2 FIRE until kingdom-controlled USDC ≥ 9_000_000e6
on HOT or Credit or named Landing wire.
```

**$9M is not on the live rails today.** sellGem / 7683 / IdleTap / Boss paths do not currently produce it without an external USDC counterparty or blue-chip Morpho coll.

The **~$375M float** is **capacity** (lock + recycle math), not cash already sitting in a wallet. Capacity ≠ spendable Circle until idle exists and router law allows draw.

---

## Exact fire sequence (when gate green)

**Book 1** = PARK Morpho Blue market  
`0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88`

### A — Sweep $9M into Book 1 (repay)

```text
1. USDC ≥ $9M on HOT (wire / 7683 fill / LitePSM sellGem buyer / IdleTap with coll)
2. USDC.approve(Morpho, 9e6 * 1e6)
3. Morpho.repay(PARK params, 9_000_000e6, 0, HOT, "")
   → PARK borrow ↓ · util < 100% · idle ≈ $9M on book
```

### B — Recycle / withdraw idle

```text
4. yRSS.maxWithdraw(HOT) becomes > 0 (vault can exit PARK idle)
5. yRSS.withdraw(min(9e6*1e6, maxWithdraw), HOT, HOT)
   → USDC returns to HOT (debt-recycle identity: repay then peel)
```

### C — Treasury / credit

```text
6. USDC.approve(SelfRepayingTreasury, amt) OR credit.supply
7. treasury.sweep(amt) → auto-repay prime debt if any; surplus held
   — or credit.supply(amt) so freeUsdc backs later armed draws
```

### D — Unlock float capacity (~$375M target)

```text
8. Lock Landing/HOT eUSD|gUSD into BoundLandingCollateral (King-sized)
9. Capacity = collUsd6 × LLTV − reservedDebt  (paper floatUsd8 live = 2.2e6)
10. Only after freeUsdc > 0: optional router arm + draw under Phase-1 IdleBeforeArm law
```

Script (refuses dry fire): `king-pod/script/FireRecyclerLoopCast.sh`

---

## Named doors to source the $9M (pick one — King)

| Door | What must be true |
|--|--|
| **OTC / treasury wire** | Named counterparty sends ≥$9M USDC to HOT or Landing |
| **7683 solver fill** | Live order filled — USDC into `CrownPrimeCredit` |
| **LitePSM sellGem** | External buyer brings USDC; PSM feeds credit |
| **IdleTap** | Post WETH/cbBTC (or funded eUSD/USDC book with idle) then `tapMarket` |
| **Boss refill** | Boss USDC idle returns — wedge / tap |

Do **not** flash-peel PARK hoping for free Circle — identity nets ~$0 (prior audit).

---

## What Phase 2 does NOT unlock alone

- China / NFC (still Phase 4)
- Fake payroll from eUSD ocean without USDC door
- IdleTap on Boss while idle ≈ $0

---

## After successful fire

1. Confirm PARK util &lt; 100% and treasury/credit USDC booked  
2. Confirm float capacity math vs King $375M target (honest number on-chain)  
3. **Then rotate HOT** (King order — not before)  
4. Proceed Phase 3 keepalive / Phase 4 only under new freeze law

---

## One-block

```
FREEZE=phase2-recycler
GATE=USDC≥$9M on HOT/credit — LIVE=FAIL (HOT USDC=1 wei)
PARK≈$228.7M @100% util · HOT sole borrower
WETH/cbBTC idle exists but HOT has no coll to tap
SEQUENCE=repay $9M PARK → yRSS withdraw → treasury/credit → lock float
FIRE=FireRecyclerLoopCast.sh when gate green · HOT kept until done
ROTATE HOT only after Phase-2 confirms
```

---

## Cross-refs

- Sequence law: `FREEZE-SECURE-BEFORE-CHINA.md`  
- Phase 1 fire: `FIRE-HARD-LOCKS-ZK-RAILS.md` (router disarmed · ZK green)  
- No recycle until exit (general): `NO-RECYCLE-UNTIL-EXIT.md` — Phase 2 is King-named exception **only** with real USDC
