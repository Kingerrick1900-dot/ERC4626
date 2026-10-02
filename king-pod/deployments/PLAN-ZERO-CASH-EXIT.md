# Zero-Cash Exit Plan — Assets You Already Hold

**Fact:** No Coinbase BTC. No stub USDC. No Morpho idle against eUSD today.  
**Capital on HOT:** ≈ **$243.7M yRSS** + **≈301M eUSD** + dust USDC.  
**Goal:** Spendable USDC on HOT without pretending flash prints cash.

---

## The only three engines (no magic)

| # | Engine | Uses | Needs from outside | USDC to HOT |
|--|--|--|--|--|
| **1** | **Repo / OTC against yRSS** | Transfer or custody yRSS shares | Counterparty USDC | **Yes — wire** |
| **2** | **Open a borrow market on what you hold** | List **yRSS or eUSD** as Morpho coll / USDC loan | Lenders deposit USDC | **Yes — after fill** |
| **3** | **Sell a slice** | DEX/OTC sell eUSD or yRSS | Buyer | **Yes — trade** |

Flash-cbBTC, Coinbase, and “internal bookkeeping unwind” are **dead** without BTC, cash, or a live borrow.

---

## Engine 1 — Repo the shares (fastest cash, off-chain settle)

**You already have the collateral.** Do not borrow against a ghost Morpho loan — **sell a forward / repo the yRSS.**

1. Freeze a **slice** (start **$500k–$2M** NAV of yRSS, not $243M).  
2. Counterparty (OTC desk / CN corridor / private lender) wires **USDC to HOT**.  
3. Atomic or escrowed: yRSS moves to their wallet or mutual escrow; or Morpho-style on-chain escrow contract.  
4. Term: repurchase with USDC+fee later, or outright sale.  
5. Scoreboard = HOT USDC after wire — **only** that number.

**Desk deliverable:** `CrownYrssRepo` escrow (optional) + one-page term already in KE-Sov packet, pointed at **yRSS balance**, not maxIn myths.

---

## Engine 2 — Permissionless Morpho door on yRSS (on-chain build)

**Problem now:** Deep idle sits on **cbBTC/WETH** books. Your coll is **yRSS/eUSD**. Wrong door.

**Build the right door:**

1. `createMarket({ loan: USDC, collateral: yRSS, oracle: $1 or TWAP, irm: AdaptiveCurve, lltv: ≤77% })`  
2. Kingdom MetaMorpho or public suppliers fill USDC.  
3. HOT `supplyCollateral(yRSS)` → `borrow(USDC)` → HOT.  
4. Until suppliers show up, borrowable = **0** — but the rail is **real** and matchable (same Falcon play as eUSD, with the asset you actually hold).

**Parallel:** keep eUSD/USDC market; it only pays when **someone else’s USDC** sits idle there (today **0**).

---

## Engine 3 — Sell inventory

1. Probe DEX liquidity for **eUSD** and **yRSS** (expect thin).  
2. Size sells to depth so price does not nuke NAV.  
3. USDC → HOT. Brutal but solvent.

---

## Sequence (King order)

```
DAY0  Slice yRSS for Engine 1 — chase wire (only path that can pay bills this week)
DAY0  Deploy Engine 2 market listing (build while OTC runs)
DAY1+ First HOT USDC from wire or thin sell → payroll
NEVER Recycle first USDC into flash/ghost loops
SCALE Borrow on Engine 2 only after external USDC supply appears
```

---

## Scoreboard

```
CASH_START=0
COLLATERAL=yRSS~$243.7M + eUSD~301M
ENGINE1=OTC/repo wire (primary)
ENGINE2=Morpho yRSS/USDC market (build)
ENGINE3=sell slice (backup)
FORBIDDEN=zero-stub cbBTC flash / Coinbase-with-no-BTC / pretend unwind
```
