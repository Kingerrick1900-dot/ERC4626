# FREEZE — Can we engineer a repay wedge (or something else)?

**Mode:** FREEZE · **no builds · no txs · no fire**  
**Follow-on to:** `FREEZE-MORPHO-LIVE-COLLATERAL.md`  
**Snap:** Base · 2026-09-25 · PARK util **100%** · yRSS deed ≈ **$1.098M** · `maxWithdraw(HOT)=0`

---

## Short answer

| Question | Answer |
|--|--|
| Can we engineer a **repay wedge** from stack **today**? | **No** — no Circle USDC on HOT/Landing/KV/PSM to repay with. |
| Is repay wedge still the **right machine** for the deed? | **Yes** — partial repay ≈ **$1.1M** unlocks the ~$1.1M yRSS claim (you do **not** need to clear the full **~$217M** HOT debt). |
| Something else that works without Circle in wallet? | **Only** foreign unmatched borrow (needs **live coll** Morpho prices) · **foreign PA / inbound USDC** · **OTC/ZK wire** · **PSM counterparty**. None of those mint Circle in-repo. |
| Build now? | **No** — freeze. Armed unwind/peel/puller code already exists; missing is **fuel**, not Solidity. |

---

## Repay-wedge physics (honest)

```
lasting_idle = supply − borrow
repay(X) without withdrawing supply  →  idle += X
yRSS.maxWithdraw opens up to idle
```

| Move | Result |
|--|--|
| **Repay ~$1.1M** then **peel ~$1.1M** yRSS → Landing | Deed → cash. Net Circle ≈ **0** (spent X, got X). Useful if Landing needs **liquid** USDC and you already have a temporary wedge. |
| **Repay ~$1.1M** and **leave idle** (no peel) | Lasting park idle ≈ **+$1.1M**. Costs X USDC equity left in the book. |
| **Flash repay → withdraw → repay flash** | Temp util drop only. Leaves **$0** lasting idle (unless equity left behind). Frees RSS coll hygiene — **not** payroll print. |
| **gasPark / same-book re-borrow** | Re-latches. Forbidden. |

**Wedge size to free the deed:** ≈ **$1.098M** USDC (match current `convertToAssets`), **not** $217M.

**Live HOT debt:** ≈ **$217.08M** (sole fat PARK borrower). Excess beyond the yRSS supply slice is the self-seed mirror — ignore for peel math.

---

## Live fuel board (can we form the wedge?)

| Source | Balance | Can repay PARK USDC debt? |
|--|--|--|
| HOT USDC | **$0** | No |
| Landing USDC | ≈ **$2.51** | Dust only |
| KingVault USDC | **$0** | No |
| PSM `0xF733…` USDC | **$0** | Empty door |
| HOT eUSD | ≈ **$2.45M** | **No** — wrong token |
| Landing eUSD | ≈ **$2.00M** | **No** |
| HOT RSS free | **0** (252k already PARK coll) | Sell needs **USDC buyer** |
| HOT cbBTC | **1028 wei** | ≈ $0 |
| HOT WETH | **0** | No |
| eUSD/USDC Morpho `0x5d46…` idle | ≈ **$0** (book ~$1.80 matched) | Cannot borrow Circle vs eUSD **yet** |

**Verdict:** Repay wedge is **engineer-ready as process**, **fuel-blocked as capital**. eUSD in wallet does not repay USDC debt. Empty PSM / empty eUSD→USDC loan book = same wall.

---

## Menu — repay wedge vs something else (freeze rank)

### W1 — Repay wedge (deed machine) — **RIGHT, BLOCKED**

**What:** Land ≈ **$1.1M** Circle on HOT → `repay` PARK → peel or keep idle.  
**Fuel:** OTC / wire / treasury / PSM `sellGem` counterparty / MM.  
**Code status:** Already armed (`CrownUnlatchIdle`, DeedPeel, Liberator, KingRail P3).  
**Freeze next:** Name **who wires $1.1M** (or smaller tranche). No new build.

### W2 — Foreign idle + live coll (skip repay) — **RIGHT, BLOCKED ON COLL**

**What:** Post coll Morpho accepts on a **deep USDC book** → borrow lasting Circle → park unmatched **or** use as repay wedge.  
| Coll | Book idle (prior snaps) | HOT has |
|--|--|--|
| cbBTC | ~$195M | **1028 wei** — need ~**23 BTC** for $1.5M |
| WETH | ~$11M | **0** |
| eUSD | USDC/eUSD idle ≈ **$0** | eUSD **plenty** — book empty |

**Freeze next:** Name coll source (cbBTC/WETH buy or loan) **or** fill USDC side of eUSD market (curator/PA). Still no build until fuel named.

### W3 — Foreign PA / inbound supply — **NO KING USDC**

**What:** Gauntlet/Steakhouse/militia vaults set **maxIn > 0** into PARK/RSS → unmatched supply opens `maxWithdraw` without HOT repay.  
**Live:** foreign **maxIn = 0**.  
**Freeze next:** Curator **packet**, not a contract.

### W4 — PSM / ingest counterparty — **ELITE INGRESS**

**What:** Someone sells USDC for eUSD into multi-PSM → sweep USDC → W1.  
**Live PSM USDC:** **$0**. Door exists; counterparty does not.  
**Freeze next:** Fee/route product + named arb/MM — not Morpho forge.

### W5 — ZK / OTC attestation → wire — **DESK, NOT STORAGE**

**What:** Prove kingdom TVL ≥ ask → desk wires Circle → W1/W2.  
**Does not:** rewrite Morpho idle.  
**Freeze next:** Prove packet + desk route.

### W6 — Partial / smaller wedge — **SAME LAW, SMALLER**

Any **X** USDC repay opens **≈X** idle / peel room. $10k wedge → $10k peel. Dust Landing **$2.51** is already the scale of “something else” without fuel — proved Unlatch ~$1.51. Scaling is capital, not code.

### Forbidden (still)

- Flash + re-borrow same book as “wedge”  
- eUSD/gUSD ocean labeled as Circle repay  
- Knot / full $217M unwind sold as treasury print  
- “Build a new puller” with no USDC/coll  

---

## What “engineer the wedge” actually means under freeze

Engineering ≠ writing another contract. Under freeze it means **picking a fuel lane and sizing it**:

1. **If King can get Circle:** W1 at **$1.1M** (full deed) or tranche **$X**.  
2. **If King can get BTC/ETH coll:** W2 size to ask; optional use borrow as W1 fuel.  
3. **If King can get a curator open:** W3 — zero wallet USDC.  
4. **If King can get a PSM buyer:** W4 → then W1.  
5. **If only kingdom eUSD:** W2 eUSD door is **correct thesis** but **loan book empty** — social fill first; posting eUSD coll today borrows ≈ **$0**.

**No builds yet** — rails/pullers/unlatch already shipped on prior branches. Missing input is **named fuel**.

---

## Recommended freeze posture

| Keep | Drop |
|--|--|
| Treat ~$1.1M yRSS as **deed** waiting on wedge or inbound idle | Building new Morpho helpers |
| Treat repay wedge as **primary peel machine** when Circle appears | Calling eUSD a repay wedge |
| Treat live-coll foreign borrow as **parallel** when coll appears | Enlarging $217M matched book |
| Scoreboard: Landing USDC · park idle · `maxWithdraw` | Script count / matched TVL |

**King decision (one line when freeze lifts):**  
`FUEL=wire|cbbtc|weth|pa|psm` · `SIZE=` · then fire **existing** W1/W2 path — do not start a build sprint.

---

## One-block

```
FREEZE=repay-wedge-menu no-builds
DEED≈$1.098M need repay≈$1.1M (not $217M)
FUEL NOW=USDC$0 PSM$0 cbBTC dust eUSD≠USDC eUSD/USDC idle≈$0
WEDGE=right machine · blocked on Circle
ELSE=live-coll foreign borrow | PA maxIn | PSM buyer | OTC/ZK wire
DO NOT BUILD — name FUEL+SIZE first
```
