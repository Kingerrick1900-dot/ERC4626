# FREEZE — King’s Orders audit (majority + spark payroll)

**Mode:** FREEZE · audit only · no broadcast  
**Handoff:** Two priorities — (1) pull full ~$200M matched book into yRSS for majority rule / 87.5% creditor control · (2) spark is live → fire payroll → MEV micro-hunt  
**As-of:** live Base reads this session

---

## Priority 2 — Spark / payroll (READY on gas; fire gated)

| Check | Live | Verdict |
|--|--|--|
| HOT ETH | `510,182,839,816,375` wei ≈ **0.000510 ETH** ≈ **~$1.53** @ $3k | Spark **live** (King’s “$1.37” band) |
| HOT USDC | `1,514,641` (~$1.51) | Extra liquid; swap **not** required for gas |
| Steakhouse shares | still `~1.0398e18` | Optional second spark; ignore for payroll |
| Nonce | **2127** · pending = latest | Clear |
| `CrownKingAgent` | `0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA` code live | OK |
| LSR `operator(agent)` | `true` | OK |
| eUSD `isMinter(LSR)` | `true` | OK |
| `firePayroll(10M e18)` estimate | **96,745** gas | @ 6e6 wei ≈ **5.8e-7 ETH** ≪ balance |
| MEV micro-hunt | **not deployed** | Post-fire phase only |

**Freeze gate:** Math says fire is cheap and wired. This freeze does **not** broadcast. Next lift after King clears freeze: `cast send` / `FIRE=1` payroll only — then specify MEV hunt scope.

---

## Priority 1 — Majority rule / pull $200M into yRSS (NOT ready)

### Gold-rail book (PARK)

Market `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88`

| Field | Raw | USD |
|--|--|--|
| `totalSupplyAssets` | `217,079,778,098,800` | **~$217.08M** |
| `totalBorrowAssets` | `217,079,778,098,800` | **~$217.08M** (100% util) |

Matched book is real. That is the gold rail.

### What yRSS actually holds on that rail

| Field | Value |
|--|--|
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| HOT roles | **owner + curator + isAllocator** |
| yRSS `totalAssets` | ~**$1.137M** |
| yRSS supplyShares on PARK | `333,294,022,318,697,678` |
| yRSS assets on PARK | **~$1.080M** |
| Share of book | **~0.50%** — **not 87.5%** |
| Gap to 87.5% of $217M | **~$188.9M** more supply inside yRSS |
| yRSS `config(PARK).cap` | **$14M** — **blocks** a $200M pull until raised |
| yRSS PA flowCaps (PARK) | maxIn/maxOut **$2M** each — not $200M |
| Foreign PA → PARK (Steakhouse / Gauntlet paths checked) | **maxIn = 0** |

### Puller system — what it can and cannot do

Existing puller stack = MetaMorpho **Public Allocator** `0xA090dD1a701408Df1d4d0B85b716c87565f90467` + scripts (`ArmYrss*`, `FirePositionSeed700k`, SpoilFire notes).

| Claim | Freeze finding |
|--|--|
| “Pull the full 200M matched book into yRSS” | **False as a unilateral action.** The $217M is mostly **other Morpho suppliers’** positions. PA `reallocateTo` moves liquidity **between vault markets that already set flowCaps** — it does not seize third-party Blue supply into yRSS. |
| “Grants 87.5% control” | **False today.** Crown is ~**0.5%** of PARK supply. 87.5% needs ~**$190M** new yRSS-sourced supply on PARK (and a cap ≥ that). |
| “King’s puller system” | **Armed only at $2M** flow on yRSS↔PARK; foreign maxIn still **0**. Raising own cap/flow is curator work; filling $190M needs **external deposits or negotiated PA inflows**. |
| 100% util | Even if caps rise, **idle is 0** — nothing to reallocate out of PARK until someone repays or new capital arrives on the supply side via yRSS deposit → queue. |

### Majority path (freeze sequence — no build yet)

1. **Raise** yRSS `submitCap` / accept for PARK to ≥ **$220M** (timelock = 0 on this vault — curator can move fast).  
2. **Raise** PA flowCaps maxIn/maxOut on yRSS↔PARK to the fill size (or staged tranches).  
3. **Source capital:** deposits into yRSS and/or foreign MetaMorpho PA maxIn toward PARK (today **0**).  
4. Only after yRSS PARK assets / book ≥ **87.5%** claim “majority creditor.”  
5. Do **not** equate Morpho matched-book TVL with Crown-controlled TVL.

---

## Order of operations (King’s intent vs freeze truth)

```
SECURE MAJORITY     →  blocked: ~0.5% now; gap ~$189M; cap $14M; foreign PA 0
FIRE PAYROLL        →  gas-ready; freeze holds broadcast
MEV MICRO-HUNT      →  not built; after payroll only
```

**Doctrine:** Kingdom takes control **only when yRSS owns the rail**, not when the rail exists. Machines fund themselves **after** payroll fire + a real MEV path — not before majority math is honest.

---

## Identity

```
book ≈ $217M matched ✓
yRSS on rail ≈ $1.08M ≈ 0.50% ✗ majority
cap $14M / PA $2M / foreign maxIn 0 ✗ pull-200M
HOT spark ≈ 0.00051 ETH ≈ $1.5 ✓ fire gas
CrownKingAgent wired ✓
MEV hunt ⊥ not deployed
FREEZE: no payroll broadcast · no fake 87.5% claim
```
