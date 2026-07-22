# $9M LOAN — DOCUMENTED PROOF + DUAL-EARN CUSTOMIZATION

**Status:** RESEARCH / PROOF ONLY. No fire. No new size invented — notional is the Kingdom’s documented **$9M**.  
**GO required** before any Elepan port broadcast.

---

## 1) Proof the $9M loan already worked (Kingdom docs + code)

| Evidence | Where |
|--|--|
| Status **FIRED on Base. ONCHAIN SUCCESS.** | `deployments/SELF-SEED-NINE-READY.md` |
| Move 1: post **18.5M RSS**, borrow **$9M** @ ≤70% LTV | same |
| Move 2: flash USDC → `yRSS.deposit` → `Morpho.borrow` → repay flash | same |
| Fork sim PASS: supply≈$9M, borrow=$9M, LTV≈**48.6%**, HF≈**1.58** | same |
| Seeder | `src/CrownSelfSeedNine.sol` (`ASK_USDC = 9_000_000e6`) |
| Script | `script/FireSelfSeedNine.s.sol` (`BORROW_USDC` default $9M) |
| Flash repay named | `REPAY_SOURCE = Morpho.borrow(RSS market)` — `FLASH-POLICY.md` + SELF-SEED-NINE |

**On-chain fee rail still live (proof query):**
- yRSS `fee()` = **10%** (`1e17`)
- yRSS `feeRecipient()` = **Landing** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`

(RSS book was later unwound — hot position now 0; the **machine and docs** are the proof the $9M path settled.)

**Less tokens then vs now:** $9M against **18.5M** RSS @ ~48.6% LTV. Elepan free ≈ **99.9M** @ soft $1 → same **$9M** is only ~**9%** LTV (more headroom, not less).

---

## 2) Morpho-documented: who earns, who pays

### Morpho Blue (market)
On `accrueInterest` (Morpho core): borrow interest is added to **both** `totalBorrowAssets` and `totalSupplyAssets`.  
→ **Borrowers pay** variable borrow rate.  
→ **Lenders (suppliers) earn** that interest in the supply index.  
Permissionless: same address may be both; Morpho still accounts both sides.

### MetaMorpho / Morpho Vault V1 (lender vault) — official fee docs
Source: https://docs.morpho.org/curate/concepts/fee/

- Performance fee = % of **interest accrued** on vault’s Morpho supply (cap 50%).  
- Collected by **minting vault shares to `feeRecipient`**.  
- Principal of depositors stays intact; fee is from profit.  
- To cash out: fee recipient `redeem()` (or approve a claimer).

**Kingdom instance:** yRSS / yELEPAN-USDC = **10%** → Landing. That is the **lender/curator earn** Morpho documents.

---

## 3) What the $9M structure made (roles)

```
Flash $9M USDC
  → deposit yVault $9M     = LENDER book (supply earns Morpho supply APY)
  → borrow $9M on coll     = BORROWER debt (pays Morpho borrow APY)
  → repay flash            = closes per FLASH-POLICY (named Morpho.borrow)
```

| Role | Position after seed | Morpho earn/pay |
|--|--|--|
| **Lender** | yVault shares (~$9M TVL) | Earns **supply interest** (share price ↑) |
| **Curator cut** | Fee shares minted to Landing | Earns **10% of lender interest** (documented) |
| **Borrower** | Morpho debt $9M + coll posted | **Pays borrow interest**; payback = `Morpho.repay` |

When hot held **both** shares and debt (classic $9M), family net ≈ borrow cost − supply earn, with **Landing fee** as the clean curator extract. That is documented — not “both sides print free USD” without a spread or external flow.

---

## 4) How to **customize the same $9M** so borrower & lender both earn + pay back

Same notional (**$9M**). Same flash skeleton (`CrownSelfSeedNine` → Elepan port). Knobs only — **King sets on GO**.

### A) Split pockets (role customize)

| Knob | Classic $9M | Dual-pocket custom |
|--|--|--|
| Vault share `receiver` | hot | **Landing** (lender/war feed) or hot |
| Debt `onBehalf` | hot | **hot** (borrower) |
| `feeRecipient` | Landing (live) | keep Landing |

Lender pocket earns supply + fee. Borrower pocket carries debt and owns coll. Same Morpho accounting.

### B) Borrower earn (Apollo/aarnâ customize — only if King GO’s the path)

Borrower earns **only** when something they hold yields **more** than borrow APY:

| Path | How (still $9M class loan) | Proof pattern |
|--|--|--|
| **B1 Collateral yield** | Apollo ACRED-style: coll itself yields | Morpho ACRED story — Elepan is soft-$1, **not** private-credit NAV unless King wraps yield coll later |
| **B2 Redeploy carry** | After (or inside) custom seed: part of liquidity lands in Steakhouse/Gauntlet; debt remains | aarnâ: loop only if carry+ |
| **B3 External borrow demand** | Outsiders borrow from the $9M book; vault lenders earn their interest; Landing takes 10% | OWN-CURATOR-MOAT.md § how fat vault works |

Without B1/B2/B3, borrower side is **cost of debt**; lender/curator side is where Morpho **documents** earn.

### C) Pay back (documented exit)

| Step | Action | Doc / mechanism |
|--|--|--|
| 1 | Borrower `Morpho.repay(USDC)` on Elepan/USDC (or RSS) market | Morpho Blue repay — frees HF / unlocks coll |
| 2 | Free idle in market (repay creates idle, or PA / deallocate) | MetaMorpho withdraw needs liquidity |
| 3 | Lender `yVault.redeem` / `withdraw` | ERC4626; fee recipient redeems fee shares per Morpho fee docs |
| 4 | `supplyCollateral` withdraw when debt cleared | Returns Elepan/RSS to wallet |

Kingdom already documented 100% util exit discipline: `NO-RECYCLE-UNTIL-EXIT.md`, Vault V2 `forceDeallocate` fork pass — **exit before recycle**.

Flash open is already payback-safe for the **flash** (same-tx). The **Morpho debt** payback is step C1 when King chooses to close.

---

## 5) Elepan port of the **same $9M** (fit check — not a fire order)

| | RSS $9M (done) | Elepan $9M (capable) |
|--|--|--|
| Coll posted | 18.5M RSS | Need ≥ ~**12.9M** Elepan @ 70% soft (HF1.55 → ~**14.0M**) |
| Free bag | was 18.5M | ≈ **99.9M** free — **fits** |
| Vault | yRSS | yELEPAN-USDC `0x61bf…145E` (fee 10%→Landing **already**) |
| Market | RSS/USDC | Elepan/USDC moat `0xa4ec…53fc` |
| Seeder pattern | `CrownSelfSeedNine` | Port — **build/fire only on King GO** |

---

## 6) Bottom line (proof)

1. **$9M self-seed is Kingdom-documented and was fired successfully** (`SELF-SEED-NINE-READY.md` + `CrownSelfSeedNine`).  
2. **Lender earn + curator fee are Morpho-documented** (Blue supply interest + MetaMorpho fee shares → Landing, live 10%).  
3. **Borrower pay + Morpho.repay payback are Morpho-documented**; flash repay was named and policy-locked.  
4. **Same $9M customizes** by splitting share receiver vs debt wallet, keeping fee→Landing, and optional carry/external demand so borrower side can earn — **King chooses knobs + GO**.  
5. Elepan has **more** coll headroom than the RSS $9M, not less.

**Awaiting King:** GO or hold · share receiver (hot vs Landing) · borrower-earn path (none / carry sink / external only) · confirm notional stays **$9M**.
