# ELEPAN PAYING SELF-SEED — CUSTOM DESIGN (PLAN ONLY)

**Status:** PLAN. No deploy until `KING_GO=1` + SIZE.

**King ask:** Custom self-seed that **actually pays** — Morpho wouldn’t settle the tx if the machine didn’t work.

---

## Why Morpho allows it (and what that proves)

Morpho Blue + MetaMorpho are **permissionless accounting**, not a free-money oracle.

| Morpho fact | What it means for us |
|--|--|
| No ban on same address supplying + borrowing the same market | Self-seed loops are **legal** on Blue (Kingdom yRSS `$9M` already settled on Base) |
| `flashLoan` must be repaid in the same tx or **full revert** | If our callback can’t deposit→borrow→repay, **Morpho won’t “allow” it** — nothing sticks |
| Blue accrues interest into `totalSupplyAssets` / `totalBorrowAssets` | The book **does** earn/pay rates on-chain |
| MetaMorpho mints **fee shares** to `feeRecipient` on interest | Curator revenue is a **first-class Morpho feature** (docs: performance fee ≤50% of interest) |
| yELEPAN-USDC already: fee **10%** → Landing `0x5Adc…2357` | Pay rail is **wired before** any seed |

So: Morpho “allowing” the loop = **atomicity + fee math work**.  
It does **not** mean a circular loop prints external USD with no counterparties.  
**Pay** = Landing fee shares (Morpho-native) + later external flow. That is the same model Steakhouse/Gauntlet curators use.

---

## What “actually pays” means (honest)

```
Borrower pays borrow interest on Blue
    → suppliers earn (vault’s Morpho supply position grows)
        → MetaMorpho takes fee% of that interest
            → mints yELEPAN-USDC shares to Landing
```

| Source | Pays Landing? | When |
|--|--|--|
| **Self matched book alone** | **Yes, small** — 10% of vault interest while util≈100% | Immediately on accrue (next vault touch) |
| **Family net cash** | Usually a **cost** (borrow ≥ supply; fee skims supply side) | Optics + fee, not payroll |
| **External depositors / borrowers** | **Yes, real** — their interest feeds vault → 10% Landing | After magnet attracts flow |
| **M2 carry** (borrow → redeploy higher APY) | **Yes** if redeploy APY > borrow + buffer | Only with listed sink |

Custom seeder goal: maximize **Morpho-settled pay** (Landing fee shares + solvent HF), not fake APY.

---

## Custom machine: `CrownElepanPaySeed`

Port of `CrownSelfSeedNine` + fat-seeder HF guards + **pay asserts**.

### Atomic path (Morpho must accept or revert)

```
1. Assert yELEPAN-USDC.fee()==10% && feeRecipient()==Landing
2. Pull Elepan → supplyCollateral(onBehalf=hot)
3. flashLoan(USDC, SIZE)                          // Morpho inventory
   onMorphoFlashLoan:
     a. yELEPAN-USDC.deposit(SIZE, receiver)      // default receiver=hot; optional fee dust to Landing
     b. require market idle >= SIZE               // same check as yRSS seeder
     c. borrow(SIZE, onBehalf=hot, to=seeder)
     d. require HF_raw >= 1.55
     e. approve Morpho repay flash                // if any step fails → Morpho reverts all
4. Optional: touch vault (deposit 0 / accrue path) so fee accounting starts clean
```

**Why this “works if Morpho allows”:** flash repayment is enforced by Morpho core. No partial seed. Same guarantee as MORE / Morpho docs leverage flash.

### Knobs (King sets on GO)

| Knob | Default | Pay / risk role |
|--|--|--|
| `SIZE` | Smoke $500k | Magnet + fee base |
| `SOFT_LTV` | 70% | Headroom under 77% LLTV |
| `MIN_HF_RAW` | 1.55e18 | Liquidation air |
| `RECEIVER` | hot | Holds vault shares (war chest) |
| `FEE_DUST_BPS` | 0 | Optional: mint tiny deposit shares straight to Landing as bootstrap |
| `IDLE_BUFFER` | 0 | If &gt;0: deposit SIZE, borrow SIZE−buffer → partial util, easier fee redeem / external borrow entry |

### Pay variant A — **FeeSeed** (recommended first)
- `IDLE_BUFFER=0` → ~100% util magnet (copy of yRSS).  
- Landing earns 10% of whatever supply interest the vault accrues.  
- Proven Morpho fee path; no foreign vault dependency.

### Pay variant B — **BufferSeed** (pays + open for outsiders)
- Deposit SIZE, borrow SIZE − buffer (e.g. 2–5%).  
- Leaves idle so (1) external borrowers can pay into **our** book immediately, (2) Landing can redeem fee shares without full unwind.  
- Slightly weaker “rate magnet,” stronger **real pay** path.

### Pay variant C — **CarrySeed** (only if sink beats borrow)
- After flash closes, or in a second tx: keep debt, redeploy spare idle only if APY math clears.  
- Not in the flash unless sink is whitelisted and liquid.  
- Skip until King names a Morpho USDC vault sink.

---

## Sketch fee sketch (not a promise)

Landing fee ≈ `vault_supply_interest × 10%`.

If magnet sits at a realized ~8% supply APY (depends on IRM/util; not guaranteed):

| SIZE | Landing fee ≈ /yr at 8% supply |
|--|--|
| $500k | ~$4k |
| $2M | ~$16k |
| $9M | ~$72k |

Self-loop still costs the hot/borrow side more than the vault side returns — **Landing is the pay pocket**. Scale pay by attracting external util, not by lying about circular APY.

---

## Build checklist (still no broadcast)

1. `src/CrownElepanPaySeed.sol` — flash callback + Landing fee asserts + HF.  
2. `script/FireElepanPaySeed.s.sol` — `KING_GO` / `FIRE_PAY` / `SIZE` / `IDLE_BUFFER`.  
3. Fork: assert Morpho reverts on broken repay; assert success end-state (TVL, debt, coll, feeRecipient).  
4. Fork: warp time → vault interaction → Landing `balanceOf` fee shares **increases**.  
5. Exit dry-run before live.  
6. King GO → Smoke FeeSeed or BufferSeed only.

Reuse: `CrownSelfSeedNine` (pay path), `CrownElepanFatFlashSeed` (HF), live yELEPAN-USDC (fee→Landing).

---

## Kill rules

1. No fire without GO + SIZE + variant (A/B).  
2. No claiming circular loop = free USDC payroll.  
3. Abort if `feeRecipient != Landing` or `fee == 0`.  
4. Abort if HF &lt; 1.55 or idle &lt; borrow.  
5. No CarrySeed without named sink APY &gt; borrow.

---

## Decision ask (King)

1. **Variant:** A FeeSeed (100% util) · B BufferSeed (idle left for real borrowers)  
2. **SIZE:** $500k · $2M · $9M · $14M  
3. **GO** → engineer builds + fork proves Landing fee shares mint → then fire
