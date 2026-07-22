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

### B) **Better access to the loan when it hits** (primary customize)

Classic $9M left util ≈ **100%**. Documented pain: after hit, **idle = 0** → next borrower cannot draw until someone repays (`BRETT-ACTIVATED.md`: “free liquidity = 0 … cannot move”).  
**Customize so when the $9M hits, the loan stays reachable.**

| Access lever | What it does at hit | Live on yELEPAN-USDC today |
|--|--|--|
| **1. Access idle buffer** | Seed deposits **$9M**, borrower leg draws **$9M − BUFFER** (flash sized to close). Residual **BUFFER** stays idle in-market → instant `borrow` when someone hits | Knob on GO (`ACCESS_BUFFER` — King names) |
| **2. Public Allocator JIT** | If idle thin, `reallocateTo` pulls vault liquidity into the market up to **maxIn**, then borrow — Morpho’s access path | PA allocator **true**, fee **0**, flow **$700k/$700k**, admin **hot** |
| **3. Raise PA maxIn at arm** | When $9M hits, $700k cap is the JIT ceiling unless King raises (e.g. toward buffer or full ask) | Change only on GO |
| **4. Hot allocator** | King/allocator `reallocate` without PA — curator access, no public fee | hot `isAllocator` **true** |
| **5. Bundler hit** | One tx: PA `reallocateTo` + `borrow` (Morpho docs) — access when user hits, atomic | Pattern ready; wire on GO |
| **6. Supply cap headroom** | Cap **$14M** > $9M → room for more lenders after hit without recap | enabled |

```
HIT (custom access):
  flash → deposit $9M to yELEPAN-USDC
       → borrow ($9M − BUFFER) to close flash   # BUFFER = King-named idle
  market idle ≈ BUFFER  →  first hit borrows immediately
  if ask > idle: PA reallocateTo (≤ maxIn) + borrow
```

**REPAY_SOURCE (flash) stays named:** `Morpho.borrow(Elepan/USDC)` for the flash leg — `FLASH-POLICY.md`.  
**Access after hit** = buffer idle + PA/hot allocator — not another flash.

Proof this is the right fix: classic seed docs themselves say pre-seed “market idle is ~$1 — cannot borrow $9M spot”; post-seed 100% util recreates the same lock for the *next* taker. Buffer + PA = access when it hits.

### C) Borrower earn (Apollo/aarnâ — only if King GO’s the path)

Borrower earns **only** when something they hold yields **more** than borrow APY:

| Path | How (still $9M class loan) | Proof pattern |
|--|--|--|
| **C1 Collateral yield** | Apollo ACRED-style: coll itself yields | Morpho ACRED story — Elepan soft-$1 unless King wraps yield coll later |
| **C2 Redeploy carry** | Buffer/ask leaves room; borrow proceeds or later ask → Steakhouse/Gauntlet iff carry+ | aarnâ: loop only if carry+ |
| **C3 External borrow demand** | Outsiders hit the accessible book; lenders earn; Landing 10% | OWN-CURATOR-MOAT.md |

### D) Pay back (documented exit)

| Step | Action | Doc / mechanism |
|--|--|--|
| 1 | Borrower `Morpho.repay(USDC)` | Morpho Blue — frees HF / unlocks coll |
| 2 | Idle returns (repay / PA / deallocate) | MetaMorpho withdraw needs liquidity |
| 3 | Lender `yVault.redeem` / `withdraw` | ERC4626; fee shares per Morpho fee docs |
| 4 | Withdraw collateral when debt cleared | Elepan back to wallet |

---

## 5) Elepan port of the **same $9M** (fit check — not a fire order)

| | RSS $9M (done) | Elepan $9M (capable) |
|--|--|--|
| Coll posted | 18.5M RSS | Need ≥ ~**12.9M** Elepan @ 70% soft (HF1.55 → ~**14.0M**) |
| Free bag | was 18.5M | ≈ **99.9M** free — **fits** |
| Vault | yRSS | yELEPAN-USDC `0x61bf…145E` (fee 10%→Landing **already**) |
| Market | RSS/USDC | Elepan/USDC moat `0xa4ec…53fc` |
| Access at hit | was ~100% util (blocked) | **custom: BUFFER + PA** (knobs on GO) |
| Seeder pattern | `CrownSelfSeedNine` | Port — **build/fire only on King GO** |

---

## 6) Bottom line (proof)

1. **$9M self-seed is Kingdom-documented and was fired successfully** (`SELF-SEED-NINE-READY.md` + `CrownSelfSeedNine`).  
2. **Lender earn + curator fee are Morpho-documented** (Blue supply interest + MetaMorpho fee shares → Landing, live 10%).  
3. **Borrower pay + Morpho.repay payback are Morpho-documented**; flash repay was named and policy-locked.  
4. **Better access at hit** = don’t recreate 100% util lock: **King-named ACCESS_BUFFER** + PA JIT (live $700k, raisable on GO) + hot allocator + optional bundler.  
5. Elepan has **more** coll headroom than the RSS $9M.

**Awaiting King GO knobs (no defaults invented as orders):**
- notional confirm **$9M**
- `ACCESS_BUFFER` (idle left at hit)
- PA `maxIn` at arm (keep $700k / raise)
- share receiver (hot vs Landing)
- borrower-earn path (none / carry / external hits)
