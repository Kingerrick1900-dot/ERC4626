# WORKING PLAN — Spendable capital · no Boss · no fantasy hops

**Mode:** AUDIT → PLAN (fire only when gate passes)  
**King premise:** spendable capital is available (Circle USDC and/or cbBTC).  
**Probe (Base · 2026-09-23):** HOT USDC **$0** · Landing USDC **~$2.51** · HOT cbBTC **dust**.  
**Gate:** do not broadcast until `HOT.USDC ≥ ASK` or `HOT.cbBTC ≥ ASK_BTC` on a fresh `cast` read.

**Verdict on `CrownAeroToCircle_16z.sol`:** still **NO**. Options 1–5 do not *source* Circle from eUSD/ocean. With spendable capital you **skip sourcing** and run the rails below.

---

## Live facts (unchanged kills)

| Claim | Live |
|--|--|
| Aero 5B → swap eUSD→WETH→USDC | Ocean = **eUSD/gUSD only**. No eUSD/WETH, eUSD/USDC, eUSD/cbBTC on Aero. Uni eUSD/USDC ≈ **$0.006**. |
| “6+ curators” eUSD→borrow USDC | Only **Boss** (~$0 idle) + empty twin. |
| Flash peel → “+$1.01M real” | Locker = **HOT** (100% PARK borrow). Flash unlock = **net ~$0** Circle (burn deed). |
| LP unstake → USDC | Returns **eUSD+gUSD** only. |
| Boss | Dust — not required for this plan. |

| Inventory | Live |
|--|--|
| HOT eUSD | ~$2.45M (**keep** — doctrine) |
| Landing eUSD | ~$2.0M |
| Ocean | 5B/5B · LP Landing ~4.98B |
| yRSS claim (HOT) | ~$1.08M · `maxWithdraw=0` (stuck in PARK @ 100% util) |
| PARK | util **100%** · HOT = sole borrower · **252k RSS** posted coll · free HOT RSS = **0** |
| Morpho cbBTC/USDC idle | **~$160M+** (door real **if** cbBTC funded) |

---

## What “spendable capital” unlocks

You no longer need Boss, Aero exits, or fake curator depth to **obtain** USDC. Capital **is** the USDC (or cbBTC that borrows USDC). The job is **allocation**, not alchemy.

Conservation law (do not violate):

```
external USDC in  =  Landing payroll  +  Morpho supply left  +  wallet dust
yRSS peel only relocates vault equity — it does not mint Circle
```

---

## PLAN S0 — Gate (mandatory)

```bash
cast call 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "balanceOf(address)(uint256)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 \
  --rpc-url $BASE_RPC_URL
# USDC 6dp: ASK_1M = 1010000000000  ($1.01M)
# USDC 6dp: ASK_700K = 700000000000 ($700k kingdom tax)
```

| Capital form | Min gate | Go to |
|--|--|--|
| **USDC** on HOT | ≥ **$700k** (tax) or ≥ **$1.01M** (deed-sized) | **S1** then optional **S2** |
| **cbBTC** on HOT | ≥ **~$12.8 BTC** for ~$1.01M borrow @ 86% LLTV (use live BTC price) | **S3** |
| eUSD only | — | **S4 OTC** only if King overrides “keep eUSD”; else stop |

If gate fails: capital is not on HOT yet — wire first. Do not fire Aero scripts.

---

## PLAN S1 — Payroll / kingdom tax (default · works immediately)

**Goal:** spendable USDC on Landing. No Morpho. No peel theater.

```
HOT USDC ──transfer──► Landing
```

| Field | Value |
|--|--|
| To | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Size | **$700k** (handoff tax) up to full spendable |
| Keep | HOT eUSD untouched |
| Kill | Do not sell eUSD to “top up” |

This is the clean 16z move when capital already exists: **pay**, don’t invent a DEX route.

---

## PLAN S2 — Deed → Landing (optional · same dollars, clears yRSS)

**Only if** King wants yRSS exited / PARK util opened for vault optics.

**Preferred mechanic (supply-open, not flash):**

1. HOT supplies **$F** USDC into PARK `0x41c08085…7d88` (lender).  
2. PARK idle becomes **$F**.  
3. `yRSS.withdraw` / DeedPeel **$F** → Landing.  
4. End: Landing **+$F**, HOT Morpho supply **+$F**, yRSS **−$F**. Kingdom USDC conserved; deed converted to Landing cash; capital remains as supply depth.

**Alt mechanic (repay-open):**

1. HOT `repay` PARK **$F** (cuts HOT borrow).  
2. Peel **$F** yRSS → Landing.  
3. End: Landing **+$F**, park debt **−$F**, yRSS **−$F**, wallet USDC **0**. Conserved; delevers instead of leaving supply.

| Do NOT | Why |
|--|--|
| Flash $F → repay → peel → repay flash | Net **~$0** after fee; burns deed for nothing if you already have $F |
| Expect peel to **multiply** capital | Peel ≠ mint |

**Fire:** existing `CrownDeedPeel` / `UNMATCH_PEEL` on branch `cursor/deed-yrss-peel-4f7f` once HOT USDC ≥ $F. Size $F ≤ ~$1.08M (vault claim).

---

## PLAN S3 — cbBTC capital → Circle borrow (institutional door)

**If spendable capital is cbBTC (not USDC):**

```
supplyCollateral(cbBTC) on Morpho 0x9103c3b4…1836
→ borrow USDC (idle ~$160M+)
→ Landing (S1) and/or lasting ops
```

| Field | Value |
|--|--|
| LLTV | 86% |
| For ~$1.01M USDC | cbBTC notional ≳ **$1.01M / 0.86 ≈ $1.175M** |
| Existing rail | `CrownCbbtcIdlePuller` `0xE55f…6F3B` (on fire branches) — arm when funded |
| Kill | Do not route eUSD→cbBTC on Aero (hop missing) |

---

## PLAN S4 — OTC (only if capital is still eUSD-shaped)

Doctrine: **keep eUSD**. OTC sell is a King override, not default.

If King names MM and accepts eUSD sale:

| Step | Action |
|--|--|
| 1 | MM wires USDC to HOT (gate S0) |
| 2 | HOT sends eUSD tranche per ticket |
| 3 | Run **S1** (and optional **S2**) |

Do not wrap OTC as `CrownAeroToCircle`.

---

## PLAN S5 — Explicit rejects (still)

| Option | With spendable capital? |
|--|--|
| 1 Aero eUSD→USDC | **Still dead** — don’t use capital to “test” empty pools |
| 2 Other eUSD curators | **Still empty** — capital doesn’t create their books |
| 3 eUSD→cbBTC via Aero | **Still dead** first hop |
| 4 Flash peel alone | **Still net ~0** — obsolete if you hold USDC |
| 5 Ocean LP→USDC | **Still dead** exit |
| A+C combined contract | **Do not write** |

---

## Recommended sequence (King has Circle)

```
1) Wire USDC → HOT until gate S0 green
2) S1: Landing ← min($700k, spendable)     // payroll / tax
3) Optional S2: supply or repay $F ≤ yRSS claim → peel → Landing
4) Keep eUSD + ocean 5B intact
5) Boss vacuum remains armed for dust refills only
```

## Recommended sequence (King has cbBTC)

```
1) Fund HOT cbBTC ≥ S3 gate
2) Borrow USDC on cbBTC/USDC book
3) S1 Landing (and optional lasting idle buffer on rail)
```

---

## Canary (before any ≥$100k fire)

| Check | Pass |
|--|--|
| Fresh `balanceOf` USDC/cbBTC on HOT | ≥ ASK |
| Recipient Landing | `0x5Adc…2357` |
| eUSD HOT balance | unchanged after USDC-only path |
| If S2: yRSS `maxWithdraw` after open | ≥ $F |
| No Aero router calls in calldata | — |

---

## One-block

```
NO CrownAeroToCircle
SPENDABLE = USDC|cbBTC on HOT (gate) — probe may still show $0 until wire
S1 transfer Landing = default win
S2 peel = relocate yRSS, conserve dollars (supply-open or repay-open)
S3 cbBTC borrow = institutional if BTC funded
KEEP eUSD · ocean 5B stays · Boss optional vacuum only
```
