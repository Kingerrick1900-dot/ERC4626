# Position → Scale Engine (LIVE RESEARCH)

**No live fire without King GO + phase flag.**  
**Banned phrase:** “when idle shows up.” That is monitoring, not engineering.

---

## 0) Live book

| Line | Amount |
|--|--|
| CDP `0x46b1…1174` coll | **25.2M Elepan** |
| CDP debt | **13.000000948M eUSD** · HF **1.938** · floor 1.55 |
| Max withdraw w/o repay | **~5.05M Elepan** |
| Mint headroom | **~3.26M eUSD** — do not use until convert works |
| Landing eUSD | **13.0M** (same issuance as debt) |
| Free Elepan (hot) | **~74.72M** |
| Liquid USDC (hot+Landing) | **~$3.65** |
| Hot WETH / ETH | **0.002 + ~0.00228** (~$15) — not scale |
| RSS / WETH CDP / cbBTC CDP | **0** |

**Matched Morpho seeds (King both sides — not free liquidity):**
| Market | Supply ≈ Borrow | Hot coll (Elepan) | Net loan extractable |
|--|--|--|--|
| Elepan/WETH | ~10.005 WETH | ~30,158 | **~0** (self-matched) |
| Elepan/cbBTC | ~0.500 cbBTC | ~51,658 | **~0** (self-matched) |
| Elepan/USDC | **$2** supply, $0 borrow | 0 | **$2** |
| RSS/USDC | ~$1 | 0 | dust |

---

## 1) Research receipt (Base, verified)

| Check | Result |
|--|--|
| UniV3 ELE/USDC or ELE/WETH (100/500/3000/10000) | **No pool** |
| Aerodrome v2 ELE/USDC, ELE/WETH, eUSD/USDC | **No pool** |
| 0x quote Elepan→USDC (1 / 10k / 1M) | **`no Route matched`** |
| Odos token list | Elepan **absent** |
| Kingdom eUSD/USDC pool | **None** |
| Aggregator path to monetize free Elepan on-chain | **Does not exist today** |

**Conclusion:** The position cannot route to USDC through public DEX/Morpho idle. Scale requires **creating** USDC depth and a venue from a **deterministic first dollar**, then running Kingdom rails.

---

## 2) Engineered plan (deterministic steps)

### Step A — First USDC (pick one; this IS the start, not a hope)

| Path | Mechanism | Why it’s engineered |
|--|--|--|
| **A1. Treasury wire** | King sends USDC size `S` to hot/Landing from off-chain | Immediate, known size |
| **A2. OTC desk** | `KingElepanSale` escrow: USDC in → Elepan out, Landing receives USDC | Uses free **74.7M Elepan** inventory at a **named price**; RFQ’d buyer |

No A1/A2 ⇒ no scale. There is no third on-chain magic path on Base today (research above).

King names: `S` (USDC) and/or OTC tranche + min price.

### Step B — Install depth into Kingdom credit (you are the liquidity)

With USDC `S` from A:

1. Deposit USDC into **yELEPAN-USDC** (`0x61bf…145E`) — King already owns curator.  
2. Allocate into Morpho Elepan/USDC (`0xa4ec…53fc`).  
3. Post Elepan collateral from free hot (and CDP withdraw ≤ ~5.05M if needed).  
4. Borrow USDC to **Landing** up to LLTV buffer (**~77%**), leaving a depth stub in the book.

**Net (example):** wire/OTC `S` → borrow ~`0.7S` to Landing → ~`0.3S` stays as owned depth.  
That is operating **your** vault/market, not waiting for strangers.

Flags: `FIRE_DEPTH=1` then `FIRE_BORROW=1` (sizes in env).

### Step C — Create the public venue (so the bag can clear)

With Landing USDC from B (and/or reserved slice of `S`):

1. Deploy **UniV3 or Aerodrome ELE/USDC** pool.  
2. Seed both sides (Elepan from free bag + USDC from B).  
3. Optional: thin eUSD/USDC pool only after PSM exists.

This **creates** the route research proved missing. Flag: `FIRE_POOL=1`.

### Step D — Convert the debt stock

1. Deploy `CrownEusdPsm` (eUSD ↔ USDC, fee → Landing).  
2. Seed reserve from Landing USDC.  
3. Only then consider extra CDP mint (`FIRE_MINT=1`).

Until D: **no new debt**. Existing 13M eUSD stays treasury inventory against the CDP.

### Step E — Amplify (optional, after A–C)

Kingdom-owned Elepan emitter and/or Merkl (if whitelist) to grow **external** USDC into the vault you already seeded. Amplification is not Step A.

---

## 3) Debt controls (real position)

1. HF ≥ **1.55**; self-liq armed below 1.50.  
2. Don’t mint into a black hole — mint only after PSM (D).  
3. Matched WETH/cbBTC books: leave or unwind for Elepan coll only; they are **not** a USDC source.  
4. Scoreboard: Landing USDC · Morpho Elepan/USDC depth · pool TVL · CDP HF · free Elepan.

---

## 4) What King must name to proceed (engineering cannot invent this)

| Input | Why |
|--|--|
| **A1 size `S` USDC** and/or **A2 OTC tranche + floor price** | First dollar — research shows no public route |
| Depth split | How much of `S` stays in market vs extracted to Landing |
| Pool seed size | Elepan + USDC for Step C |
| Phase flags | Exact `FIRE_*=1` per step |

---

## 5) One-line plan

> **Buy or wire the first USDC on purpose → stuff it through your own yELEPAN/Morpho rails against the Elepan debt book → borrow to Landing → seed ELE/USDC + PSM.**  
> Idle is something you **install**, not something you wait for.
