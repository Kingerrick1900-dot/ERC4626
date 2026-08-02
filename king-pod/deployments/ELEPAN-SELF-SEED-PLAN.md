# ELEPAN SELF-SEED + COPY-CAT LOOP — PLAN ONLY (NO FIRE)

**Status:** PLAN. No deploy / no broadcast until King says `KING_GO=1` + size + which phase.

**Doctrine:** Self-seed = depth/optics, not free capital. Pay from fee/idle/external only.  
Matched books ≠ payroll. Scoreboard = vault TVL · market util · fee shares to Landing · HF ≥ 1.55.

---

## The copy-cat pattern (what the market actually runs)

Same Morpho Blue machine used by retail, funds, and Coinbase-backed flow:

```
Deposit collateral → Borrow loan → Buy more / redeploy → Redeposit → Repeat
```

Usually packed into **one tx** via `Morpho.flashLoan` → `onMorphoFlashLoan` (MORE Optimizer, Morpho docs “leverage in one flash,” Kingdom fat seeder callback shape).

| Who | How they use it |
|--|--|
| **Retail / yield farmers** | Loop 3–5× into Morpho markets chasing supply APY + borrow incentives; Gauntlet/Steakhouse USDC vaults are the depth they borrow against |
| **Institutions / desks** | Collateralize (often tokenized credit / own paper) → borrow stables → redeploy; scale is vault TVL + risk curator, not a new primitive |
| **Coinbase “DeFi mullet”** | Crypto-backed loans on Morpho; deposit side through Morpho Vaults curated like Steakhouse (caps, queues, PA flow) — **same curator model Kingdom already shipped** |
| **MORE Optimizer** | Automated leverage manager; flash callback + dynamic loop count vs util target |

**Kingdom position:** rails match that stack (own market + MetaMorpho + PA + flash callback). What is missing is the **seeded magnet** and then the **copy-cat earn loop** against it. Window for incentive-chasing loops compresses as TVL fills — measured in months; machine must be ready when external capital shows.

---

## Two machines (do not conflate)

| Machine | Pattern | What it is | Earn |
|--|--|--|--|
| **M1 — Curator magnet** | Flash USDC → `yELEPAN-USDC.deposit` → borrow same USDC → repay | Bootstrap from **zero** TVL/util (Kingdom `$9M` yRSS play) | Optics + **10% fee → Landing** when outsiders arrive |
| **M2 — Copy-cat leverage loop** | Deposit Elepan → borrow USDC → **buy more Elepan or redeploy to yield** → redeposit → repeat (N loops, flash-atomic) | Same play retail/MORE/institutions run | Carry = (yield or incentives on redeploy) − borrow APY − fees; loops amplify |

`CrownElepanFatFlashSeed` already implements the **callback skeleton** (flash → Morpho ops → repay).  
It currently runs a **matched book** (supply loan = borrow loan), which is **M1 optics for WETH/cbBTC**, not full M2 “buy more collateral.”  
M2 needs an explicit **swap or redeploy leg** inside the callback.

---

## Rails already live (inputs)

| Piece | Address / state |
|--|--|
| Elepan (8dp) | `0x50639C42…4583` · hot free ≈ **99.92M** |
| Oracle Elepan/USDC soft $1 | `0xe290…cf19` · price `1e34` |
| Market Elepan/USDC | `0xa4ec…53fc` · **empty** (0/0) |
| yELEPAN-USDC | `0x61bf…145E` · TVL **0** · cap **$14M** · fee **10%→Landing** · PA **$700k** · TL **2d** |
| Morpho USDC flash inventory | ≈ **$184M** on Morpho |
| Fat seeder (callback live) | `0x24622EB0…4688` — WETH/cbBTC matched books done |
| Hot USDC | dust — flash required for both machines |

Soft $1 × 77% LLTV on free Elepan ≈ **~$77M** theoretical. Vault hard cap **$14M**. Soft LTV target ≤ **70%**.

---

## Phase plan (still NO FIRE)

### Phase 0 — Curator parity (DONE)
Own oracle, Elepan/USDC moat, yELEPAN-USDC, PA caps, 10%→Landing, 2d TL. Same Steakhouse-shaped surface Coinbase depositors already trust on Morpho.

### Phase 1 — M1 magnet bootstrap (first GO)
Mirror `CrownSelfSeedNine`:

```
supplyCollateral(Elepan)
flashLoan(USDC, SIZE)
  deposit yELEPAN-USDC → supplies moat
  borrow SIZE onBehalf hot
  repay flash
→ ~100% util magnet + vault TVL ≈ SIZE
```

| Tranche | SIZE | Coll @ 70% | Note |
|--|--|--|--|
| Smoke | $500k | ~714k Elepan | Prove path |
| Ops | $2M | ~2.86M | Real magnet |
| Fortress | $9M | ~12.9M | Match old yRSS notional |
| Cap | $14M | ~20M | Vault cap |

**Recommend:** Smoke → Ops after fork PASS. M1 alone is not “25–30% APY”; it **creates the book** others loop into.

### Phase 2 — M2 copy-cat loop (after magnet or with external idle)

Atomic (MORE-shaped), `onMorphoFlashLoan`:

```
flash USDC (or flash Elepan)
  buy Elepan (DEX) OR skip buy if King already holds bag
  supplyCollateral(Elepan)
  borrow USDC up to soft LTV
  redeploy USDC → earning sink (see below)
  OR repeat coll/borrow N times (3–5) then settle
repay flash
```

**Redeploy sinks (pick on GO — Morpho-native only):**

| Sink | Role | When |
|--|--|--|
| **yELEPAN-USDC** | Own vault; fee → Landing | Always available post-Phase 1 |
| **Foreign Morpho USDC vault** (Steakhouse/Gauntlet-class) | Earn their supply APY vs our borrow | Only if borrow APY + buffer &lt; vault APY (+ incentives) |
| **Incentive farm** | Borrow/supply MERKL or partner rewards | Only if Elepan market / vault is **actually listed** — do not invent APY |

**King-bag shortcut:** with ~100M Elepan already on hot, “buy more” is optional. First institutional copy is: **post bag → borrow → redeploy to yield vault → optional second loop**, not forced DEX buy.

**Loop count:** 1 (smoke) → 3 → 5 max (retail range). Each loop raises LTV toward soft 70%; HF floor **1.55** hard-stop.

### Phase 3 — External capital trigger (revenue)
Publish deposit addresses (yELEPAN-USDC, FHE/sleeve, ZK credit). Outsiders running M2 against **our** market pay borrow interest → vault suppliers earn → **10% fee → Landing**. That is the revenue loop the clock is about.

---

## Curator rules (Kingdom = Steakhouse seat)

| Rule | Value |
|--|--|
| Soft LTV | ≤ **70%** (LLTV 77% − buffer) |
| Min HF raw | ≥ **1.55** (alert 1.60) |
| Max loops / tx | **5** |
| Fee | **10%** → Landing |
| Supply cap | **$14M** (raise only on GO) |
| PA flow | **$700k** (raise only on GO) |
| Queue | Elepan/USDC only |
| Timelock | **2 days** |
| Min M1 tranche | ≥ **$500k** |
| Incentive claim | Only if on-chain reward distributor exists for this market/vault |

---

## Build checklist (PLAN — no broadcast)

1. `CrownElepanSelfSeed` — Phase 1 M1 (port of `CrownSelfSeedNine`, Elepan 8dp).  
2. `CrownElepanCopyCatLoop` — Phase 2 M2 (fat-seeder callback + N loops + redeploy sink whitelist).  
3. Fork sims: M1 Smoke/Ops; M2 loops=1/3 with HF asserts + unwind.  
4. Exit path: repay → unwrap vault / deallocate (no strand).  
5. King GO → fire Phase 1 Smoke only → observe → scale / unlock Phase 2.

---

## Honest earn math (so nobody lies to the throne)

- **No Morpho incentives listed on Elepan yet** → cannot quote “9.7% borrow reward” on this book until a real program attaches.  
- Circular M1 earn ≈ fee skim on own interest (small) until **external** flow.  
- M2 earn only if **redeploy APY (+ incentives) > borrow APY + buffer**.  
- Fat-flash matched books are **depth**, not a money glitch.

---

## Kill rules

1. No live fire without `KING_GO=1` + phase + size (+ loops for M2).  
2. No selling M1 as free USDC or payroll.  
3. No M2 without listed sink APY math or King-held collateral path.  
4. No invented incentive APYs.  
5. No RSS recycle into this loop.  
6. Fork exit fail → freeze scale.

---

## Paying custom — SUPERSEDED AS PRIMARY

**Primary plan is now borrow→redeploy carry:** `ELEPAN-PAY-SEED.md` (King **$14M** → Steakhouse/Gauntlet).  
Self-seed / FeeSeed = demoted optics only.

## Decision ask (King)

1. Idle source for $14M borrow: external · King supply-only · hold?  
2. Sink: best APY at fire / name one?  
3. Receiver: Landing (rec) / hot?  
4. **GO** → build `CrownElepanCarry` + fork + fire
