# FREEZE — Engineer idle from the billion-dollar stack (no “add USDC” lecture)

**Mode:** FREEZE · explain only  
**Order:** Use **what is already ours**. Stop treating the stack as empty.

---

## Where the USDC already is

| Layer | What it is | Size |
|--|--|--|
| **Park Morpho USDC** | Real Circle USDC in market `0x41c0…7d88` | ~**$203M** supply book |
| **Kingdom claim on that USDC** | HOT yRSS shares | ~**$1.01M** `convertToAssets` |
| **Unlocked now** | `maxWithdraw` = park unmatched | ~**$1.51** |
| **Why $1.01M won’t peel** | Same book is ~**100% utilized** — USDC is **matched** (borrowed), not missing | — |
| **Foreign unmatched USDC** | cbBTC/USDC + WETH/USDC books | ~**$183M** + ~**$11M** idle (not our supply; **borrowable with coll**) |

So: the **$1.01M is already Circle USDC inside Morpho**. Engineering = **unmatch** it (or borrow foreign unmatched), not mint it.

Landing USDC ≈ **$0.20**. Puller / rail engineered lasting idle so far = **$0** (armed only). Unlatch proved the machine at **$1.51**.

---

## What the “billions” are (stack inventory)

| Asset | Role in engineering |
|--|--|
| HOT ~**2.45M eUSD** + Landing ~**2M eUSD** | Liquid **kingdom** stable — Morpho eUSD idle / pipe — **≠** Circle |
| HOT ~**2.03B gUSD** + Aero **5B/5B** ocean | Militia optics / magnet — **≠** Circle |
| Landing Morpho eUSD supply | Sole big supplier on eUSD book — withdrawable as **eUSD** |
| RSS coll on park | Already posted; selling needs a **USDC buyer** |
| ZK gate `0xca2a…3f30` | `minThreshold=$700k` · HOT **`isProven=false`** — **OTC door**, not Morpho storage rewrite |
| Public Allocator on yRSS | Cap / reallocate plumbing — **opens door for foreign USDC**, does not print it |
| CbbtcIdlePuller + KingRail P3/P4 | Code that pulls foreign book idle **when coll exists** — coll in stack today = **1028 wei** |

---

## Engineer-from-stack menu (by any means we actually have)

### E1 — Unmatch the USDC already in park (share → cash / idle)
**Means:** Temp or lasting open of park idle so yRSS can move the **$1.01M that is already USDC**.  
**Stack fuel that works:** asset that can **repay park debt** or **repay a flash from another USDC book**.  
**In-stack today:** no free USDC, no cbBTC size, eUSD/gUSD **cannot** repay USDC debt.  
**Armed code when fuel appears:** KingRail P3 (payroll peel) · P4 / Puller (lasting idle).  
**Honest freeze:** E1 is the right *machine*; stack is short the *key* (coll or USDC wedge), not short the claim.

### E2 — ZK militia attestation → wire (stack as collateral narrative)
**Means:** Prove kingdom TVL / notes / ocean / eUSD at gate ≥ **$700k** → desk / militia rails **wire Circle USDC** into HOT → Unlatch / Puller / park supply.  
**Uses:** billions + ZK layer as designed.  
**Does not:** write Morpho balances from the proof alone.  
**Freeze next:** lift only to build **prove packet + desk route**; Morpho fire after wire lands.

### E3 — Allocator / foreign PA (militia USDC walks into our market)
**Means:** HOT curator sets **PA maxIn** on park / rss40; Gauntlet / Steakhouse / militia vaults deposit USDC → unmatched supply = lasting idle; yRSS withdraw opens.  
**Uses:** allocator + live markets.  
**Zero** king wallet USDC required.  
**Freeze next:** curator packet + maxIn number — not a Morpho forge script.

### E4 — Ocean / rate magnet (already live)
**Means:** 5B/5B + Morpho eUSD idle + park rates suck **inbound** USDC into PSM/park.  
**Uses:** militia currency as magnet.  
**Every inbound USDC** → `engineerIdle` / createIdle / pull → Landing.  
**Already built.** Wait / incent — don’t re-mint Morpho USDC.

### E5 — Liquidate kingdom eUSD stack as eUSD (not Circle)
**Means:** P1 Landing withdraw eUSD · P2 pipe — **already fired ~$2M eUSD to Landing**.  
**More eUSD idle** via FakeIdle mint path = more **kingdom** idle.  
**Label:** real for eUSD rails; **forbidden** to call it Circle payroll.

### E6 — RSS / BRETT / inventory → USDC buyer
**Means:** OTC or pool sale of kingdom inventory to anyone holding USDC → same as wire into E1.  
**Stack:** RSS on park + other inventory per handoff.  
**Freeze:** name buyer; don’t pretend Aero eUSD/gUSD pool pays Circle.

### E7 — Forbidden (not engineering — lying to the book)
- ZK / proof → Morpho USDC balance  
- gasPark / same-book flash borrow as “idle”  
- PSP `eUSD→USDC` with **0** reserves  
- “Shares alone” 2-tx payroll with no coll / no wire  

---

## Single freeze doctrine

> **The USDC is in the Morpho park book and in foreign cbBTC/WETH books.  
> Our shares are the deed to ~$1.01M of it.  
> Our billions + ZK + allocator are how we bring a key (wire, PA, coll) to unmatch or borrow that USDC.  
> Our pullers/rails are the locks already cut.  
> Engineering from this stack = turn deed + key + lock — not mint Circle.**

---

## Freeze scoreboard (live)

| Meter | Now |
|--|--|
| Lasting park idle engineered | **$1.51** (Unlatch) |
| Puller `totalIdlePulled` | **0** |
| Rail USDC liberated / idle engineered | **0 / 0** |
| yRSS deed | ~**$1.01M** |
| Peelable now | ~**$1.51** |
| ZK HOT proven | **false** |
| cbBTC on HOT | **1028 wei** |
| Foreign cbBTC book idle | ~**$183M** |

**Seat:** Next freeze choice is **E2 packet**, **E3 maxIn**, or **name coll/wire for E1** — not another “can’t.” The stack has the deed and the machines; pick the key.
