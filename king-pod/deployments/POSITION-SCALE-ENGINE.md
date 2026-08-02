# Position → Scale Engine — FLASH BOOTSTRAP

**No live fire without King `KING_GO=1` + `FIRE_ELEPAN_SEED=1`.**

`$2` vault TVL is the **start of bootstrap**, not a stop. Morpho holds **~$200M USDC** you can flash. Same machine as the RSS `$9M` self-seed you already proved.

---

## 0) Live book

| Line | Amount |
|--|--|
| CDP coll / debt / HF | **25.2M Elepan** / **13.0M eUSD** / **1.938** |
| Free Elepan (hot) | **~74.7M** |
| yELEPAN-USDC TVL | **~$2** ← empty magnet, rails live |
| Morpho USDC inventory (flashable) | **~$199.9M** |
| PA maxIn yELEPAN→Elepan/USDC | **$700k** (already set) |

---

## 1) Bootstrap (access the loan — flash)

**Path = `CrownElepanSelfSeed` (RSS Nine pattern):**

```
post Elepan coll
  → Morpho.flashLoan(USDC)          // from protocol inventory, NOT the $2 market
  → yELEPAN-USDC.deposit            // installs depth into Elepan/USDC
  → Morpho.borrow(onBehalf king)    // REPAY_SOURCE (same tx)
  → repay flash
```

**End state (like SelfSeedNine):**
- Hot holds **yELEPAN shares** = war chest / vault TVL  
- Morpho **debt ≈ flash size** against Elepan coll  
- Wallet USDC unchanged (flash closes)  
- Fee rail: yELEPAN **10% → Landing**  
- Book is no longer a $2 joke — it’s a seeded market

| Size example | Elepan coll (70% soft) | Flash / vault TVL |
|--|--|--|
| Probe | ~14.3M | **$10M** |
| Nine-size | ~12.9M+ | **$9M** (default) |
| Fat | ~50M | **~$32M** (cap raise if >$14M vault cap) |

Vault supply cap today **$14M** — first fire ≤ $14M unless King raises cap.

---

## 2) After seed (still GO-gated)

1. **External idle / PA** — real USDC lenders or curator `flowCaps` on top of seeded book → extra borrow to **Landing** (spendable).  
2. **Own emitter** — Elepan rewards into yELEPAN (optional amp; Merkl optional).  
3. **ELE/USDC pool + PSM** — once Landing has USDC from (1) or named sale.

Step 1 is “find access to the loan” beyond flash: PA / foreign MetaMorpho allocation into **your** market.

---

## 3) Fire (King only)

```bash
cd king-pod
# prep deploy + Morpho auth + approve (no seed)
KING_GO=1 forge script script/FireElepanSelfSeed.s.sol:FireElepanSelfSeed \
  --rpc-url $RPC --broadcast --slow

# fire bootstrap
KING_GO=1 FIRE_ELEPAN_SEED=1 BORROW_USDC=9000000000000 ELEPAN_COLL=0 \
  forge script script/FireElepanSelfSeed.s.sol:FireElepanSelfSeed \
  --rpc-url $RPC --broadcast --slow
```

`ELEPAN_COLL=0` → use full free hot Elepan (script still enforces 70% LTV).  
`REPAY_SOURCE=Morpho.borrow(ELE_USDC)`.

---

## 4) What this is / isn’t

| Is | Isn’t |
|--|--|
| Bootstrap using **flash access** to Morpho USDC | Leaving flash USDC in the pool unpaid |
| Vault TVL + borrow book + fee rail **on purpose** | Claiming wallet payroll equals flash size |
| The same engineered path as RSS Nine | Waiting for strangers to fill a $2 vault first |

---

## 5) One-line

> Flash Morpho’s USDC into **your** yELEPAN against **your** Elepan coll, close the flash with the borrow — bootstrap the book, then take spendable USDC when external/PA liquidity sits on top.
