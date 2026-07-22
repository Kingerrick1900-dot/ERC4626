# ELEPAN SELF-SEED LOOP — PLAN ONLY (NO FIRE)

**Status:** PLAN. No deploy / no broadcast until King says `KING_GO=1` + size.

**Doctrine:** Self-seed = depth/optics, not free capital. Pay from fee/idle/external only.  
Matched books ≠ payroll. Scoreboard = vault TVL · market util · fee shares to Landing · HF ≥ 1.55.

---

## Why this play (Morpho-from-zero only)

King filter: **only plays used by protocols that bootstrapped Morpho markets/vaults from empty books.**

| Play (Morpho-native) | Who used the pattern | What it does |
|--|--|--|
| **A. Own oracle + isolated market** | Every Morpho Blue curator (Steakhouse, Gauntlet, Moonwell, Kingdom RSS) | Niche book; no Chainlink herd |
| **B. Own MetaMorpho + supply queue → that market** | Same curators | Depositors fund *your* book |
| **C. Atomic flash self-seed** | Kingdom `$9M` yRSS (`CrownSelfSeedNine`); same Morpho flash + vault deposit + borrow repay path Morpho docs enable | From-zero TVL + 100% util rate magnet without outside USDC |
| **D. Public Allocator flow caps** | Morpho PA standard (curator `maxIn`/`maxOut`) | JIT liquidity; borrowers pull idle into ask market |
| **E. Matched fat-flash book** | Elepan WETH/cbBTC already (`CrownElepanFatFlashSeed`) | Market optics before vault magnet |
| **F. Timelock + caps harden** | MetaMorpho risk model | Raise risk slow; bootstrap TL then lock |

**Rejected (not Morpho-from-zero / not earning):** dust carry toys, foreign-curator begging as the primary bootstrap, self-loop sold as “free USDC,” recycle stranded RSS without exit GO.

---

## What “loan that really earns” means here

Two layers — do not confuse them:

1. **Rate-magnet loan (Play C — primary)**  
   Hot posts Elepan → flash USDC → `yELEPAN-USDC.deposit` → vault supplies Elepan/USDC market → `Morpho.borrow` same size → repay flash.  
   - End: Morpho debt + yELEPAN-USDC shares on hot + Elepan coll locked.  
   - Net carry on the circular leg ≈ **vault fee skim (10% → Landing)** when interest accrues; borrower and vault supplier are the same economic family until outsiders arrive.  
   - **Earns when:** external depositors chase the high util rate, and/or external borrowers pay against Elepan coll. Fee rail is the real earn.

2. **External carry (optional later — only if idle ≠ self)**  
   Borrow USDC that is **not** immediately re-supplied as the sole depth of the same book, and deploy into a Morpho-listed earn path whose supply APY > borrow APY after fees.  
   - Requires true idle or external depositors first.  
   - Do **not** call circular self-seed “carry.”

---

## Rails already live (inputs)

| Piece | Address / state |
|--|--|
| Elepan (8dp) | `0x50639C42…4583` · hot free ≈ **99.92M** |
| Oracle Elepan/USDC soft $1 | `0xe290…cf19` · price `1e34` |
| Market Elepan/USDC | `0xa4ec…53fc` · **empty** (0/0) |
| yELEPAN-USDC | `0x61bf…145E` · TVL **0** · cap **$14M** · fee **10%→Landing** · PA **$700k** · TL **2d** |
| Morpho USDC flash inventory | ≈ **$184M** on Morpho (headroom ≫ plan sizes) |
| Matched books (already) | 10 WETH + 0.5 cbBTC via fat seeder |
| Hot USDC | dust (~$0.06) — flash required |

Soft $1 × 77% LLTV on free Elepan ≈ **~$77M** theoretical max. Vault hard cap = **$14M**. Soft LTV target ≤ **70%** (same as `$9M` RSS play).

---

## Proposed loop (atomic — mirror `CrownSelfSeedNine`)

```
1. Pull Elepan from hot → Morpho.supplyCollateral(Elepan/USDC, onBehalf=hot)
2. Morpho.flashLoan(USDC, SIZE)
   onMorphoFlashLoan:
     a. approve + yELEPAN-USDC.deposit(SIZE, hot)   // vault → supplyQueue → moat market
     b. Morpho.borrow(SIZE, onBehalf=hot, receiver=seeder)
     c. approve Morpho repay flash
3. End state:
   - market supply ≈ market borrow ≈ SIZE  (≈100% util magnet)
   - yELEPAN-USDC TVL ≈ SIZE (shares on hot)
   - Morpho debt ≈ SIZE on hot
   - Elepan coll posted (SIZE / 0.70 soft LTV)
   - wallet USDC ≈ 0 (flash closed)
```

**REPAY_SOURCE:** `Morpho.borrow` against freshly posted Elepan + vault-created idle in the same market (identical to yRSS self-seed).

### Size ladder (King picks one; no fire until GO)

| Tranche | SIZE USDC | Elepan coll @ 70% soft | LTV vs free bag | Notes |
|--|--|--|--|--|
| Smoke | **$500k** | ~714k | ~0.5% | Prove seeder + PA optics |
| Ops | **$2M** | ~2.86M | ~2% | Real magnet; still tiny LTV |
| Fortress | **$9M** | ~12.9M | ~9% | Same notional as RSS `$9M` play |
| Cap | **$14M** | ~20.0M | ~14% | Hits vault supply cap |

Default recommendation for first GO: **Smoke $500k → Ops $2M** after fork PASS. Scale only with HF ≥ 1.55 and exit path tested.

---

## Curator rules (Kingdom owns — Morpho-shaped)

Set / keep these as law for the loop (already mostly on-chain for yELEPAN-USDC):

| Rule | Value | Why |
|--|--|--|
| Soft LTV | ≤ **70%** (LLTV 77% − buffer) | Liquidation air |
| Min HF raw | ≥ **1.55** (alert 1.60) | Same as fat seeder |
| Fee | **10%** → Landing | Earn rail |
| Supply cap | **$14M** | Match yRSS-era magnet |
| PA flow | **$700k** maxIn/maxOut | Morpho PA discipline; raise only on GO |
| Queue | Elepan/USDC **only** | Own moat, no foreign markets |
| Timelock | **2 days** | Already hardened |
| Min tranche | ≥ **$500k** | No dust seeds |
| Dead deposit | Optional dust to `0xdead` on first live | MetaMorpho inflation guard (WETH vault pattern) |

**PA after seed:** keep fee=0; flow caps stay $700k until King raises. Magnet does not need PA for the atomic self-seed (vault supplies directly). PA is for later external borrow UX.

---

## Build checklist (still PLAN — no broadcast)

1. Port `CrownSelfSeedNine` → `CrownElepanSelfSeed` (Elepan 8dp math, yELEPAN-USDC, moat market params).  
2. Script `FireElepanSelfSeed.s.sol` with `KING_GO` + `FIRE_SEED` + `SIZE_USDC` knobs.  
3. **Base fork sim** for Smoke + Ops: assert TVL, util≈100%, LTV, HF, flash closes, Landing fee recipient.  
4. Exit dry-run: repay borrow → withdraw vault / `forceDeallocate` path (do not strand).  
5. Only then: King GO → fire Smoke → observe → scale.

Reuse patterns: `CrownSelfSeedNine` (vault magnet), `CrownElepanFatFlashSeed` (callback + HF guards). Do **not** reuse RSS seeder address for Elepan.

---

## Earn path after magnet is live

| Phase | Action | Earn source |
|--|--|--|
| T0 | Self-seed (circular) | Optics only; fee accrual on own interest is small |
| T1 | External USDC into yELEPAN-USDC | Supply APY at high util; **10% fee → Landing** |
| T2 | External Elepan borrowers | Real borrow demand; vault suppliers earn; fee skim |
| T3 | Optional carry | Only with **non-circular** idle; Morpho-listed earn > borrow |

Sleeve / FHE / ZK credit remain **external-deposit** rails — they do not replace this magnet.

---

## Kill rules

1. No live fire without `KING_GO=1` and explicit SIZE.  
2. No calling self-seed “free capital” or payroll.  
3. No tranche &lt; $500k.  
4. No raise PA flow / vault cap without GO.  
5. No recycle of old RSS inventory into this loop.  
6. If fork exit fails → freeze scale (see `NO-RECYCLE-UNTIL-EXIT.md` spirit).

---

## Decision ask (King)

Pick: **Smoke $500k** · **Ops $2M** · **Fortress $9M** · **Cap $14M** · or hold.

On GO: engineer builds seeder + fork PASS, then fires chosen tranche only.
