# Real Paths That Deliver — UPDATED

**Doctrine:** Fortress is built. Wrong lever = theater. No self-advance circularity.  
**No broadcast without King GO + phase flag.**

---

## Live fortress (now)

| Piece | State |
|--|--|
| CDP | 25.2M Elepan · ~13.00017M eUSD debt · HF **1.938** |
| Landing eUSD | **13.0M** (matches principal; fee accrued ≈ **$142**) |
| Free Elepan | **~34.58M** hot |
| CDP max withdraw (no repay) | **~5.05M** Elepan |
| yELEPAN-USDC | **~$14M** · shares on Landing |
| ZK attest | **$1M** proven · max draw **$700k** · pool **$0** |
| Hot USDC | **~$1.61** — **not** a buyer |

---

## Killed: self-advance

Funding hot with $500k to draw $490k from ZK credit is circular. Hot stays out as buyer.

---

## Four options that actually deliver

### 1) ZK / “Babylon” borrow — external supply, then draw
**Works.** Gate live, $1M attested, 70% cap = $700k.  
**Block today:** credit `0xc415…d936` has **$0**.  
**Fix:** counterparty `supply(ASK)` → `FIRE_ZK_CREDIT` `ASK_USDC=490000000000` (or 500k) → Landing.  
No hot self-fund. First external dollar into the credit pool unlocks the rail.

### 2) CDP native repay → withdraw Elepan
**Works — no external USDC required for the unlock.**  
Landing already holds 13M eUSD against the debt.

| Call | Meaning |
|--|--|
| `repay(amt)` | Burns eUSD from Landing/treasury; partial OK |
| `withdraw(eleAmt)` | Pulls Elepan if HF stays ≥ safety floor (1.55) |
| `repayWithdrawCollateral()` / `close()` | **Full** exit only — not a partial tool |

**Not Morpho’s** `repayWithdrawCollateral` — Kingdom CDP’s own API.  
**False path killed:** “mint 50–100k from fee accrual first.” Live fee ≈ **$142**. Ignore that step.

**Real partial flow:**
1. Size repay from Landing eUSD  
2. `repay`  
3. `withdraw` Elepan (keep HF ≥ 1.55)  
4. Free Elepan joins the ~34.58M bag for OTC / pool seed / Morpho coll  

Without repay, **~5.05M** Elepan is already withdrawable.

### 3) OTC against ZK-proven bag
**Works for same-day cash.**  
Packet live ($1M attest, CDP HF 1.94, free + withdrawable Elepan).  
Counterparty advances USDC vs attestation and/or buys withdrawn Elepan off-market.  
~$2M+ economic buffer vs 77% Morpho LLTV framing on the 25.2M book.

### 4) Flash — only with a named repay source
Morpho flash for matched vault seed = **done** (optics/magnet).  
Flash USDC → Landing without idle to re-borrow = **dead**.  
Flash WETH → USDC → seed DEX requires real WETH inventory (hot ≈ dust) + repay path — not a $490k door today.  
Allowed only when `REPAY_SOURCE` is proven same-tx (FLASH-POLICY).

---

## What works right now (ordered)

| Priority | Action | Needs GO |
|--|--|--|
| **A** | Name OTC / ZK credit supplier for **$490k** (or $500k) into credit or wire to Landing | Counterparty + `FIRE_ZK_CREDIT` |
| **B** | CDP `repay` + `withdraw` to free more Elepan surface (uses Landing eUSD you already have) | `FIRE_CDP_PARTIAL=1` + sizes |
| **C** | Optional: withdraw ≤ ~5.05M Elepan with **no** repay (HF stays safe) | `FIRE_CDP_WITHDRAW=1` |
| **D** | After USDC exists: seed Elepan/USDC DEX + emitter | later flags |

**Barrier:** not the contracts — first external USDC or OTC buyer into the credit pool / wire.

---

## Corrections vs bad advice

| Claim | Reality |
|--|--|
| Generate 50–100k eUSD from fees | Fee ≈ **$142** — useless for repay sizing |
| `repayWithdrawCollateral` = partial | On Kingdom CDP it is **full close** |
| Hot self-supply $500k → draw $490k | Circular — rejected |
| $490k is sitting in the credit pool | No — it’s an **authorization cap**; pool is empty |

---

## One-line

> Use Landing eUSD to **repay/withdraw** Elepan when you want surface; use **ZK credit or OTC** when you want USDC — the $490k path is real the moment someone `supply`s the pool.
