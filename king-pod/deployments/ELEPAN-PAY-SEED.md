# ELEPAN CARRY — PLAY-FOR-PLAY (PRIMARY PLAN)

**Status:** PRIMARY. Self-seed circular magnet = **weak / demoted**.  
**King-named notional:** **$14M** working capital (borrow → redeploy), not idle self-skim.  
**No fire until explicit `KING_GO=1`.**

---

## Why self-seed is weak (agreed)

| | Self-seed | Carry (this plan) |
|--|--|--|
| Flow | Borrow ↔ supply same book | Borrow USDC → **foreign** yield |
| Earn | Fee from yourself | **Spread** + Landing AUM on outsiders |
| Institutional match | Optics only | Coinbase/Steakhouse lenders + Babylon-style coll→borrow→redeploy |

`$490k` ZK line stays a side rail (pool empty). Lever = **Elepan bag + Morpho borrow + redeploy**.

---

## Gold copies

- **Coinbase / Steakhouse:** external USDC into curated Morpho vaults; borrowers post coll; curator fees on AUM.  
- **Babylon-shaped:** attest/hold coll → borrow USDC on Morpho → redeploy to yield (ZK attest already live on hot; Blue still needs Elepan posted for standing borrow).  
- **Apollo / aarnâ:** loop/redeploy **only when carry+** (sink APY ≥ borrow + buffer).

---

## Stack map

| Component | Live piece |
|--|--|
| Collateral | ~99.9M Elepan on hot → post to Elepan/USDC moat |
| Market | `0xa4ec…53fc` · LLTV **77%** · soft $1 oracle |
| Borrow ask | **$14M** USDC (≤70% soft LTV · HF ≥1.55) |
| Redeploy sink | **Foreign** Morpho USDC vault — *not* back into same moat as sole depth |
| Default sinks | Gauntlet USDC Prime `0xeE8F…b61` · Steakhouse Prime `0xBEEF…b2` · Steakhouse USDC / HY |
| Curator fee | yELEPAN-USDC **10% → Landing** on **external** deposits |
| Access | PA `$700k` JIT (raise on GO) · hot allocator |

**Do not** redeploy borrowed USDC into yELEPAN if that vault’s only market is the same Elepan/USDC book you borrowed from — that recreates circular self-seed. yELEPAN is for **outside lenders**; carry sink is **Steakhouse/Gauntlet-class**.

---

## Chicken-egg (honest — must solve before $14M borrow)

Morpho Blue borrow needs **idle USDC** in Elepan/USDC. Idle sources (pick on GO):

| # | Source | Notes |
|--|--|--|
| 1 | **External** USDC → yELEPAN-USDC (cap $14M) | Best — real lenders; then borrow against their depth |
| 2 | **King supply-only** USDC into yELEPAN or Morpho supply | Not circular if you don’t borrow that same dollar back as the earn story |
| 3 | Demoted: flash self-seed optic | Only if King forces depth with no external USDC — **not** the earn engine |

Carry **starts** when idle ≥ ask (or idle + PA maxIn ≥ ask).

---

## Play-for-play

### Act 0 — Preflight (no broadcast)
1. Confirm hot Elepan ≥ ~22M for $14M @ HF 1.55 (bag has ~99.9M — OK).  
2. Confirm yELEPAN fee→Landing, cap $14M, queue=moat, PA live.  
3. Quote live **borrow APY** (Elepan/USDC) vs **sink supply APY** (+ incentives).  
4. **Abort unless** `sinkAPY ≥ borrowAPY + 150bps`.

### Act 1 — Create idle (King picks source)
- **1A External:** publish deposit addr; wait until `totalAssets` / market idle ≥ ask path.  
- **1B King USDC:** supply-only into yELEPAN (or Morpho supply) — size ≥ $14M or ≥ ask + buffer.  
- Do **not** call this “carry.”

### Act 2 — Post collateral
```
Elepan.approve(Morpho)
Morpho.supplyCollateral(Elepan/USDC, coll, onBehalf=hot)
```
Soft LTV after borrow ≤ **70%**. HF ≥ **1.55**.

### Act 3 — Take the loan ($14M working capital)
```
if idle < 14M: PublicAllocator.reallocateTo(yELEPAN → moat) within maxIn
Morpho.borrow(USDC, 14M, onBehalf=hot, receiver=hot|carrySafe)
```
Optional Morpho **bundler**: reallocate + borrow one tx.

### Act 4 — Redeploy (the earn)
```
USDC.approve(SINK)
SINK.deposit(14M, receiver=Landing)   # kingdom feed pocket
```
Sink = whitelist only (Steakhouse/Gauntlet).  
**Pay = sink yield − borrow interest** (net to Landing/hot per receiver).

### Act 5 — Run / bound
- Monitor HF, borrow APY vs sink APY.  
- If spread &lt; 150bps → **unwind** (Act 6), don’t add loops.  
- Optional bounded loops (aarnâ-style) only on GO, max 3, soft LTV 70%.

### Act 6 — Pay back
```
SINK.redeem → USDC
Morpho.repay(USDC)
Morpho.withdrawCollateral(Elepan)
```
Exit tested before any recycle (`NO-RECYCLE-UNTIL-EXIT` spirit).

---

## Scoreboard that matters

| Metric | Target |
|--|--|
| Morpho debt | **$14M** (on GO) |
| Sink assets (Landing) | ≈ **$14M** |
| Spread | ≥ **150bps** or flatten |
| Landing yELEPAN fee shares | ↑ when **outsiders** deposit |
| HF | ≥ **1.55** |

Not: circular util %, self-fee crumbs, empty ZK pool cosplay.

---

## Build on GO (not before)

| Piece | Role |
|--|--|
| `CrownElepanCarry` | coll → borrow → sink deposit; spread + HF gates |
| `FireElepanCarry.s.sol` | `KING_GO` / `ASK_USDC=14e6*1e6` / `SINK=` / `FIRE_CARRY=1` |
| Fork | negative spread reverts; full unwind works |

---

## Decision ask (King) — then GO

1. Idle source: **external** · **King supply-only** · hold?  
2. Sink: **best APY at fire** · or name Steakhouse Prime / Gauntlet Prime?  
3. Sink shares receiver: **Landing** (recommended) · hot?  
4. Explicit **GO** → build Carry + fork → fire $14M borrow→redeploy
