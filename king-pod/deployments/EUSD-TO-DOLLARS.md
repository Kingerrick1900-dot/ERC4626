# eUSD → real dollars — three doors (LIVE)

**Token to import / swap:** Kingdom eUSD `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a`  
**(Not** Electronic Dollar `0xcfa3…` — different token, ignore DEX charts for that address.)

## Book right now
| Where | Amount |
|--|--:|
| Landing (cold) eUSD | **~13,815,133** |
| Hot eUSD (kept) | **814,000** |
| Total eUSD | **~14,629,133** (matches CDP debt book) |
| Landing Elepan | **~75,980,606** |
| Landing USDC | **~$5.65** |
| CDP coll still posted | **~23.94M Elepan** · HF ~1.64 |

eUSD is **real and already minted**. Nothing else must be minted to “have” it.  
What is missing is a **clear into USDC/USD**.

---

## Live research (Base, just verified)

| Check | Result |
|--|--|
| Aerodrome eUSD/USDC (stable + volatile) | **No pool** (`0x0`) |
| UniV3 eUSD/USDC (100 / 500 / 3000 / 10000) | **No pool** (`0x0`) |
| Aerodrome ELE/USDC | **No pool** |
| DexScreener for Kingdom eUSD | **No pairs** |
| Aggregator route eUSD→USDC | **None** (no venue to quote) |
| `CrownEusdPsm` | **Not deployed** (never shipped) |
| Old `CrownPsm` `0x3fbb…4ecf` | **kUSD only** — wrong token, do not use |

**Verdict:** You cannot “just swap” in a wallet today. Public DEX path does not exist yet for *this* eUSD.

---

## The three doors (simple)

### Door 1 — PSM (protocol redeem, cleanest)
**What it is:** Kingdom contract that swaps **eUSD ↔ USDC** near $1 (fee → Landing).

**What we need:**
1. Deploy `CrownEusdPsm` (soft peg, fee, pause, caps, USDC reserve).
2. Seed the PSM with **real USDC** (size = how much eUSD you want to clear).
3. Then: send eUSD in → get USDC out to Landing.

**First dollar for the reserve comes from Door 2 or Door 3** (or a treasury wire).  
No USDC in the PSM ⇒ no redeem.

### Door 2 — Uniswap / Aerodrome pool
**What it is:** Public eUSD/USDC (or ELE/USDC) pool so anyone can swap.

**What we need:**
1. Permanent USDC (wire / OTC / buyer) — **not** flash liquidity.
2. Create pool (Aero stable eUSD/USDC **or** UniV3).
3. Seed both sides (eUSD or Elepan + USDC).
4. Prefer: **PSM first**, thin pool second (docs order).

**Status:** pool address = none. Create + seed required before any wallet swap works.

### Door 3 — Real buyer (OTC / MM)
**What it is:** Named desk buys eUSD and/or Elepan for USDC.

**What we need:**
1. King names buyer + size + floor price.
2. Buyer sends USDC to Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`.
3. King sends eUSD (and/or Elepan) to buyer (or via escrow sale contract).

**Fastest path to spendable dollars** if a desk is ready. No pool required.

---

## What is *not* a dollar door
| Action | Result |
|--|--|
| Mint more eUSD (~814k headroom) | More eUSD — **still not USDC** |
| CDP `repay` with eUSD | Burns debt / frees Elepan — **restructuring, not dollars** |
| Morpho idle borrow | Needs **external USDC idle** — separate rail |
| Confusing with Electronic Dollar eUSD | Wrong token — has pools; **yours does not** |

---

## Simple order to cash
1. **Name Door 3 buyer** *or* **wire USDC** to Landing (size `S`).  
2. Optionally stand up **Door 1 PSM** with that USDC → redeem eUSD→USDC at peg.  
3. Optionally seed **Door 2 pool** with a slice of USDC + eUSD/ELE for public clear.

Until one of those three has **USDC on the other side**, the 14.63M eUSD stays Kingdom units — real credit, not payroll dollars.

## Addresses
```
eUSD:     0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a
Elepan:   0x50639C42E2FFDEC4F68FB468968a55b3Af944583
USDC:     0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
CDP:      0x46b1D159b3a2694e7b70F550b7d5dEf6df451174
Hot:      0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
Landing:  0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
Aero fact:0x420DD381b31aEf6683db6B902084cB0FFECe40Da
UniV3 fact:0x33128a8fC17869897dcE68Ed026d694621f6FDfD
```
