# LANDING $700k USDC — Engineering Plan

**Target:** `Landing 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` holds **700,000 USDC** (6dp).  
**Now:** Landing USDC ~$2.41 · Landing eUSD ~$700,027 · Morpho RSS/$1200 idle ~$0 · PA foreign maxIn = 0.  
**Doctrine:** loan don’t sell RSS/ELE · own rails first · Morpho matched book stays unless a named unwind GO.

Composer / custom flash = **execution machine only**. It does not mint unmatched USDC inside a 100% util book. Every track below ends with **USDC balance on Landing**, with a named USDC source.

---

## End state (success criteria)

```text
USDC.balanceOf(Landing) >= 700_000e6
RSS Morpho coll on hot unchanged UNLESS Track 2 borrow uses existing headroom only
No RSS market sell
```

---

## TRACK 1 — RSS-secured USDC loan desk (PRIMARY · fastest close)

**USDC source:** a lender (desk / MM / treasury line) — not Morpho idle.  
**King posts:** free RSS (~9.76M on hot).  
**Pattern:** isolated collateralized loan (same industry shape as Composer debt tools; no pool needed).

| Step | Action | Detail |
|--|--|--|
| 1.1 | Deploy `CrownRssUsdcDesk` | RSS in · USDC out to Landing · LTV ≤ 75% · oracle = Morpho RSS `$1200` feed `0xB584…E1B9` |
| 1.2 | Lender `fund(700_000e6)` | USDC from lender wallet → desk |
| 1.3 | King `draw(rssIn, 700_000e6, Landing)` | Lock **≥ 778 RSS** (at $1200, 75% LTV); send **700k USDC → Landing** |
| 1.4 | Optional Composer wrap | Single tx: `transferFrom RSS` + `draw` + assert `balanceOf(Landing)` |

**Size math**

| USDC out | LTV | RSS lock @ $1200 |
|--|--|--|
| 700,000 | 75% | ≥ **778 RSS** |
| 700,000 | 50% | ≥ **1,167 RSS** |

**Gate:** name lender + USDC line. Inventory (RSS) is already enough.  
**Fire script:** `FireRssUsdcDesk.s.sol` (build on GO).  
**Does not touch** Morpho $200M book.

---

## TRACK 2 — Morpho borrow after idle appears (Composer / SpoilFire)

**USDC source:** foreign (or own) supply allocated into RSS/$1200 so idle ≥ $700k.  
**King already has:** 220k RSS coll · ~**$3.28M** LTV headroom to 77% LLTV · SpoilFire `0xcFF6…45Fa`.

| Step | Action | Detail |
|--|--|--|
| 2.1 | Open PA `maxIn ≥ 700_000e6` | Gauntlet USDC Prime `0xeE8F…b61` + Steakhouse Prime `0xBEEF…b2` on market `0x41c08085…bf7d88` |
| 2.2 | `reallocateTo` / PA pull | Idle USDC lands in RSS/$1200 |
| 2.3 | Borrow `700_000e6` onBehalf hot → **Landing** | Composer flow **or** `CrownSpoilFire` |
| 2.4 | Assert | `USDC.balanceOf(Landing) >= 700_000e6` · HF safe |

**Composer flow (correct — not flash-sweep fantasy)**

```text
1. PA.reallocateTo(RSS_MARKET, ≥700k)     // CREATES idle
2. morphoBlue.borrow(700k → Landing)      // DRAWS idle
3. (no flash repay against the same 700k)
```

If idle is created by **King flash-supply** then borrow-to-repay-flash, Landing gets **$0**. Do not ship that recipe.

**Gate:** maxIn > 0 (curator packet). Live today: maxIn = **0**.  
**This is the Morpho door other desks describe** — the missing switch is **maxIn**, not Composer.

---

## TRACK 3 — Atomic eUSD → USDC (OTC / Composer swap)

**USDC source:** counterparty.  
**King pays:** Landing eUSD (~$700k already minted).

| Step | Action | Detail |
|--|--|--|
| 3.1 | Escrow / Composer dual-leg | Counterparty deposits `700_000e6` USDC |
| 3.2 | King sends `700_000e18` eUSD | From Landing (or hot after pull) |
| 3.3 | Release USDC → Landing | Atomic: both legs or revert |

**Gate:** named buyer for eUSD at ~$1.  
**Keeps** Morpho book · **uses** eUSD already on Landing.

---

## TRACK 4 — Bluechip loan → deep Morpho → PSM (BACKUP · already forked)

Doc: `GO-B-BLUECHIP-USDC-PSM.md` · PR #105 · fork PASS.

| Step | Detail |
|--|--|
| 4.1 | WETH lender funds `CrownRssWethDesk` (~**427 WETH** for $700k @ ~86% path) |
| 4.2 | Post WETH on Morpho WETH/USDC `0x8793…1bda` (idle ~$8M+) |
| 4.3 | Borrow USDC → `MultiPSM.seed` `0xF733…F987` |
| 4.4 | `redeemAsset` eUSD → USDC on Landing |

**Gate:** WETH inventory/lender. Heavier than Track 1 (Track 1 takes USDC direct).

---

## Forbidden recipes (do not fire)

| Recipe | Result on this board |
|--|--|
| flash USDC → borrow RSS market → repay flash → “sweep” | **$0** on Landing (borrow pays flash) |
| flash USDC → supply + borrow same amount → repay | self-seed expand · **$0** wallet |
| flash → PSM seed → redeem eUSD → repay flash | burns eUSD · **$0** net USDC |
| sell RSS into Aero (~$0.67 depth) | doctrine break · can’t size $700k |

---

## Tonight fire order

1. **Confirm Track** — **1** (USDC lender) · **2** (PA maxIn) · **3** (eUSD buyer) · **4** (WETH lender).  
2. **Name counterparty + size** (default **700_000e6**).  
3. **GO** → deploy/script → broadcast → paste Landing USDC balance.

**Recommended default:** **Track 1** — fewest hops, RSS already free, USDC lands in one `draw`.

---

## Addresses (Base)

| Role | Address |
|--|--|
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| RSS | `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| RSS/$1200 market | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| PA | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| Multi-PSM | `0xF7337A26d9456e42a36531A12036A4556EF1F987` |

---

## Build checklist (on GO for Track 1)

- [ ] `CrownRssUsdcDesk.sol` — fund / draw / repay  
- [ ] `FireRssUsdcDesk.s.sol` — draw `700_000e6` to Landing  
- [ ] `RssUsdcDeskFork.t.sol` — fork PASS assert Landing ≥ 700k  
- [ ] Live broadcast · verify `USDC.balanceOf(Landing)`  
- [ ] Update this doc with tx hashes  
