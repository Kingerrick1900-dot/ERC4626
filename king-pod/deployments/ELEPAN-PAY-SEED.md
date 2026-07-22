# KINGDOM WIN PLAN — BORROW OUR ASSET, EARN REAL USDC

**King law:** We put up **our** Elepan. We take a Morpho loan. We **earn**.  
**Not** last time’s circular self-seed. **Not** a scribe plan that unwinds to **zeros**.

**Status:** PRIMARY plan. **No fire until `KING_GO=1`.**  
**Ask:** **$14M** USDC working capital (King-named).

---

## Why last self-seed failed the kingdom (proof)

| Last play (RSS $9M) | End state |
|--|--|
| Flash → deposit **own** yRSS → borrow same USDC → repay flash | Matched book / optics |
| “Earn” = fee on yourself | Not outsider yield |
| Later unwind / free | Hot RSS Morpho position **0**, yRSS TVL **dust** — **zeros** |

Kingdom docs: `SELF-SEED-NINE-READY.md` (fired) → later free/unwind paths → on-chain now **empty**.  
**We will not run that machine again as the earn engine.**

Others (Apollo ACRED, Coinbase/Steakhouse vaults, Babylon-style coll→borrow→redeploy) grow by **borrowing against an asset and parking USDC where someone else pays yield** — not by lending to themselves.

---

## This plan (different machine)

```
OUR ASSET          Morpho loan              REAL EARN
Elepan posted  →  borrow $14M USDC  →  deposit FOREIGN Morpho USDC vault
(soft $1 moat)     (standing debt)      (Steakhouse / Gauntlet — outsiders’ book)
                         ↓
              pay borrow APY from sink yield
              KEEP THE SPREAD + Landing fee on external yELEPAN deposits
```

| | Last self-seed | Kingdom win (this) |
|--|--|--|
| Collateral | Our token | Our token (**Elepan**) — same |
| Borrow | USDC | USDC **$14M** — same shape |
| USDC destination | **Own** vault → **same** market | **Foreign** vault (Steakhouse/Gauntlet) |
| Who pays us | Ourselves | **Other** borrowers / vault strategy |
| Scoreboard | TVL optic | **Landing sink shares ↑ in USDC** · HF safe · spread ≥ 150bps |
| Allowed to end at zero | Happened | **Forbidden** — unwind only with retained earn or King exit GO |

---

## Morpho check (no laughing zeros)

1. **Blue standing borrow** requires coll — we have ~99.9M Elepan. We post **ours**.  
2. **Idle USDC** must exist in Elepan/USDC before $14M borrow (external into yELEPAN, or King supply-only). No idle = no loan — we don’t fake it with circular flash-and-call-it-earn.  
3. **Redeploy** only to whitelist sinks with live TVL (Base):  
   - Steakhouse Prime USDC `0xBEEFE94c…83b2`  
   - Gauntlet USDC Prime `0xeE8F4eC5…b61`  
   - Steakhouse USDC / HY beef vaults  
4. **Fire gate:** `sinkAPY ≥ borrowAPY + 150bps` or **abort** (aarnâ rule).  
5. **Receiver:** sink shares → **Landing** (kingdom money). Debt on hot.  
6. **Exit:** redeem sink → repay Morpho → free Elepan. Never “optics only” close that wipes the feed.

yELEPAN-USDC stays the **external lender** magnet (10% fee → Landing).  
Borrowed $14M does **not** go back into yELEPAN as the carry sink.

---

## Play-for-play (kingdom win)

### 0) Preflight
- Elepan free ≥ ~22M for $14M @ HF 1.55 (have ~99.9M).  
- Quote borrow APY vs sink APY. Abort if spread thin.  
- Name idle source.

### 1) Idle (real depth — not self-lend cosplay)
- External USDC → yELEPAN **or** King supply-only USDC.  
- Until idle (+ PA ≤ maxIn) covers **$14M**, no borrow.

### 2) Put up the asset
`supplyCollateral(Elepan)` on moat `0xa4ec…53fc`, onBehalf=hot.

### 3) Take the loan
`borrow($14M USDC)` → working capital to carry safe / hot.  
PA `reallocateTo` if needed within flow caps (raise on GO if King wants).

### 4) Earn
`SINK.deposit($14M, Landing)`.  
Monitor spread weekly; flatten if carry dies.

### 5) Win scoreboard (non-negotiable)
- Landing sink assets ≈ $14M **plus** accrued yield (not zero).  
- Morpho debt serviced; HF ≥ 1.55.  
- Optional: outsider yELEPAN TVL → Landing fee shares.  
- **If a path only produces matched util and unwind dust — reject.**

### 6) Pay back when King says
Redeem sink → `repay` → withdraw Elepan. Retain net USDC earned on Landing.

---

## Build only on GO

`CrownElepanCarry` + `FireElepanCarry.s.sol`  
Knobs: `ASK_USDC=14000000000000` · `SINK=` · `KING_GO=1` · `FIRE_CARRY=1`  
Fork must prove: spread gate, Landing balance after deposit, full unwind restores Elepan with **non-zero** net if yield accrued (time-warp).

---

## Decision ask (King)

1. Idle: **external** · **King supply-only** · hold?  
2. Sink: **Steakhouse Prime** · **Gauntlet Prime** · best APY at fire?  
3. Confirm: **no circular self-seed** as earn engine?  
4. **GO**
