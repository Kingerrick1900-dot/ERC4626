# CHIEF PLAY — King sits = nothing. Here is the play.

**Side:** King Errick of Yahudah.  
**Fact:** RSS has **~$14.2M Morpho buying power** @ $1 / 77% LLTV. Proven **~$9M**.  
**Fact:** Sitting on empty books converts **$0** of that power into Landing cash.

---

## The play (one sentence)

**Use the Blue market as the credit line — force USDC onto the other side of that book — borrow to Landing. Desk runs in parallel to place size for USDC.**

Blue market = the option. Not BRETT (empty + no BRETT). Not idle-watch costume. **Blue RSS/USDC.**

---

## Why Blue (not sit)

Morpho accepted RSS ⇒ collateral credit line.  
Credit line only pays when **USDC is supplied** into that market (direct supply or Public Allocator from vaults that hold USDC).  
Kingdom already built: market, burned oracle, yRSS, PA caps **~$700k**, desk **700k @ $1**.  
Missing piece is **the other side of the trade** — USDC facing RSS. Sitting does not create that face.

---

## Dual track (both real — run together)

### TRACK A — Blue market: unlock the $14.2M line (PRIMARY)

**Morpho 2025–26 pattern that works:** borrowers pull JIT liquidity via **Public Allocator** when **foreign curator vaults** set `maxIn` on your market.

| Now | Need |
|-----|------|
| Gauntlet / Steakhouse PA → RSS | **0 / 0** (door closed) |
| Kingdom PA on yRSS → RSS | **~$700k** armed (our door) |
| RSS market idle | **~$0** |

**King move (human — 1 message):** send the curator packet (below) to Morpho curator contacts / forum / whoever opens vault markets. Ask:

> Enable Public Allocator `maxIn` ≥ **$700k–$5M** on Kingdom RSS/USDC market  
> `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`  
> Collateral RSS @ FixedOracle $1 (owner burned). Proven ~$9M borrow. Curator: Kingdom yRSS.

**Scribe move (when any maxIn opens):** fire PA pull → borrow → **Landing** (`FireCashLeg500` / `FireKingLoanRestore`). Code ready. No new invention.

That is how Blue buying power becomes cash without selling the whole bag.

---

### TRACK B — Desk: place the token for USDC (PARALLEL — fill the disk)

Desk already live:

| | |
|--|--|
| Desk | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` |
| Ask | **700,000 RSS @ $1 = $700,000** → Landing |
| Buyer tx | approve USDC → `buyWithUsdc(700000000000)` |

**King move:** one counterparty, one packet (`OPS-COUNTERPARTY-PACKET.md`).  
This places RSS where capital meets it. Not begging for a loan — **selling Morpho-marked inventory**.

---

## What is NOT the play

| Idea | Call |
|------|------|
| Sit and wait for idle to appear | Dead |
| BRETT borrow today | Nah — $0 idle, 0 BRETT |
| Flash → Landing payroll | Algebra lie |
| New empty Blue market | No USDC face = same problem |

---

## Order of operations (tonight → week)

1. **King:** send curator PA ask (Track A) + desk packet to one real buyer (Track B).  
2. **Scribe:** standing on fire scripts — PA/cash-leg the second any USDC faces the Blue book; desk already armed.  
3. After first **$700k** on Landing: pause desk if desired, rest, then scale Blue line with deeper maxIn.

---

## Curator ask (copy/paste)

**Subject:** PA maxIn — Kingdom RSS/USDC (Base)

Market id: `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`  
Loan: USDC · Collateral: RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337`  
Oracle: FixedOracle $1 `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` (owner `dEaD`)  
LLTV: 77% · IRM: AdaptiveCurve  
Request: Public Allocator **maxIn ≥ $700,000** (prefer $1M–$5M) on this market from your Base USDC vault.  
Borrower/curator: Kingdom · yRSS `0xF80C0529bD94C773844E459853CD91B9263dD525`  
Proof: prior ~$9M utilization against this oracle mark.

---

**Chief call:** Blue market is the play for the buying power. Desk is the parallel placement.  
**King sits = $0. King sends two messages = machine can fire.**
