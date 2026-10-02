# Plan — Open the cbBTC/USDC Door ($166M Idle)

**Status:** ENGINEERED · not fired  
**Market:** Morpho cbBTC/USDC `0x9103c3b4…1836` · LLTV **86%** · idle ≈ **$166.6M**  
**Doctrine:** One atomic tx. Lender USDC only. No fairy remainder math.

---

## Why the scribe’s 5-step as written reverts

Flash asset = **cbBTC**. Repayment asset = **cbBTC**.  
Borrowed asset = **USDC** ≤ **86%** of oracle value.

You cannot “repay the flash with a portion of the borrowed USDC” directly.  
You must **buy cbBTC** with USDC to close the flash. At a fair oracle/DEX:

`buyback ≈ 100% + slip + fee` vs `borrow ≤ 86%` → **shortfall ≥ 14%**.  
Zero-upfront, keep-the-rest → **impossible**. Tx reverts or needs equity.

That is the door. The Kingdom has been kicking the handle; the latch is LTV.

---

## The plan that works (three rails, ordered)

### Rail A — Equity stub + flash (on-chain, atomic) → USDC to HOT + Morpho debt

**Goal:** End with USDC in HOT and a healthy Morpho borrow (duration risk = Kingdom’s loan).

**Stub required (USDC or cbBTC):**

```
shortfallRatio ≈ (1 - LLTV) + slip + flashFee
               ≈ 0.14 + 0.005 + 0.00   (Balancer fee often 0)
stub ≥ targetHotUsdc * shortfallRatio / LLTV
```

Rough: to land **$1M** USDC in HOT and leave a solvent position, stub ≈ **$160k+** USDC (or cbBTC notionally equal), not zero.

**Atomic sequence (`CrownFlashCollat` — to build when stub funded):**

1. `flashBorrow` cbBTC amount `C` (Balancer/Aave — wherever cbBTC liquidity exists).  
2. `morpho.supplyCollateral(cbBTC/USDC, C, HOT)`.  
3. `morpho.borrow(USDC, B, HOT, HOT)` with `B ≤ LLTV * oracle(C)` and `B ≤ marketIdle`.  
4. DEX swap `S` USDC → `C + fee` cbBTC (`S` from borrowed `B` + **stub**).  
5. Repay flash cbBTC.  
6. Remaining USDC on HOT = `B + stubUsdc - S` (≥ `minRetain` or revert).  
7. Emit `DoorOpened(C, B, retained, debtShares)`.

**End state:** HOT holds retained USDC · Morpho shows cbBTC coll + USDC debt · no free mint.

**Live blockers today:** HOT USDC ≈ **$0.01** · HOT cbBTC = **257 wei**. Stub not funded → **do not fire**.

---

### Rail B — Coinbase BTC-backed USDC (fastest real cash ≤ $100k)

1. King pledges BTC on Coinbase loan product.  
2. Receive USDC (cap per their product, often ~$100k class).  
3. Bridge/send USDC to HOT.  
4. Optional: buy cbBTC, supply Morpho, borrow more idle against **owned** coll (no flash shortfall).

**This agent cannot operate Coinbase.** King executes; desk wires HOT address.

---

### Rail C — OTC / CN corridor (size path toward tens of M)

1. OTC desk (HK/SG licensed) sells USDC vs BTC/fiat/RSS terms.  
2. USDC → HOT or Landing.  
3. Same as B: owned capital → optional Morpho loop for more borrow against acquired cbBTC.

**Not a contract.** Term + settlement. Desk opens ticket; on-chain only after USDC arrives.

---

## What “professional desks” actually do

| Pattern | Needs | Nets USDC in wallet? |
|--|--|--|
| Flash coll + borrow + buyback | Equity stub or arb | Only stub/arb edge |
| Owned cbBTC → borrow idle | cbBTC | **Yes** — up to LLTV × coll |
| Vault/PA withdraw | Vault supply shares | **Yes** — up to free liquidity |
| Zero equity flash “keep remainder” | — | **No** at 86% LLTV |

Idle **$166M** is real. Claim on it without equity is not.

---

## Immediate Kingdom checklist

1. **Fund stub** on HOT: USDC and/or cbBTC sized to target (Rail A), **or**  
2. **Execute Rail B** for first real payroll USDC, **or**  
3. **Open Rail C** OTC for size.  
4. Only then: deploy/fire `CrownFlashCollat` / measured borrow with `minRetain`.  
5. Never fire zero-stub Path 1 — it is not resistance; it is arithmetic.

---

## Sizing snapshot (live at plan write)

| Item | Value |
|--|--|
| cbBTC/USDC idle | ≈ **$166.6M** |
| LLTV | **86%** |
| HOT USDC | dust |
| HOT cbBTC | dust |
| Next gate | **stub or OTC/Coinbase USDC/BTC** |

```
DOOR=cbBTC/USDC idle~$166M
LATCH=LLTV86 + flash must repay cbBTC
KEY=stub|owned-cbBTC|Coinbase|OTC
FIRE=only after key funded + minRetain set
```
