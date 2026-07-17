# OPPORTUNITY PLAN — replace lost gas / make USDC

**Mode:** research only. No txs. King's hot / Cake / fleet / desk / Morpho / yRSS **not touched**.

**What was lost (honest):** gas on dust-seed + earlier Play 5→3. Kingdom USDC still exists on his addresses; gas is the real hole. This plan replaces that with **external** protocol profit.

---

## Live Base scan (now)

| Book | Idle USDC | HF≤1 covered liqs | Near (HF 1.05–1.08) |
|------|-----------|-------------------|---------------------|
| cbBTC/USDC (~$1.4B) | ~$147M | **0** | several $100–$1k |
| WETH/USDC (~$76M) | ~$7.9M | **0** | **best watch: ~$20.6k borrow @ HF 1.060** |
| cbETH/USDC | ~$0.6M | **0** | small |
| King RSS/USDC | **$1.50** (his dust) | n/a | PA shared = only his yRSS $1 |

**Kill:** USR/RLP HF≪1 zombies — coll << debt → liquidating **loses** USDC. Not in plan.

**Kill:** Uni USDC↔WETH roundtrip — negative after fees this block.

---

## PLAN (ranked — what works)

### 1. STRIKE watcher → fire on HF cross (PRIMARY)
**Opportunity:** Major Morpho USDC books are healthy *now*, but WETH/cbBTC have **17 sized-ish positions** sitting HF 1.05–1.08. One WETH position ~**$20k borrow / $25k coll @ 1.060** — a ~6% WETH dip puts it underwater.

**How money is made:**
1. Agent wallet (NOT Kingdom) holds gas only
2. Bot polls Morpho GraphQL + on-chain `position` every block / few seconds on:  
   `cbBTC/USDC` `0x9103…1836`, `WETH/USDC` `0x8793…1bda`, top cbETH markets
3. When **HF &lt; 1** and `collateralUsd >= 0.9 * repayUsd` (skip bad debt):
   - Morpho `flashLoan` USDC → `liquidate` → swap coll on Uni/Aero → repay flash → **profit to King receive (Cake)**
4. Partial liq first if full close kills edge
5. Sim floor: profit ≥ gas×3 (start **$5**)

**Needs to arm:** agent-only key + dust ETH gas (not fleet). Liquidator contract or one-shot script. Profit receiver = Cake (receive-only — correct for inbound).

**Why this replaces losses:** protocol liquidation bonus from *other borrowers*, not King's pocket.

---

### 2. Same-block backrun (STRIKE+)
When an oracle update / big swap pushes HF through 1.0, submit liquidate in the same block (public mempool or builder if available on Base).

**Needs:** watcher from Plan 1 + fast submit path. Same profit receiver.

---

### 3. Idle sniper on foreign float (SECONDARY — only if external USDC enters King RSS)
If **non-King** USDC hits RSS market idle (PA from foreign vault, or stranger supply):
- Borrow to Cake via SpoilFire / Play 3 against existing RSS collateral headroom
- **Do not** seed this with King's hot again

**Live now:** only King's own $1.50 idle + yRSS $1 shared — **not** foreign. Watch only until external.

---

### 4. DEX flash arb (OPTIONAL, strict)
Morpho flash → 2-leg Base route → repay → leftover to Cake.  
**Rule:** fire only if sim PnL &gt; floor. Live spot check: WETH/USDC roundtrip **no edge**. Keep as cron, not hope.

---

## NOT in this plan
- Touch King hot / Cake outbound / fleet / desk / yRSS / Morpho King position
- Play 5→3 relocate theater
- Send ops USDC to Cake (receive-only)
- Liquidate bad-debt USR books

---

## Deliverable if King says GO on Plan 1
1. Generate **agent wallet** address (Kingdom keys unused)
2. King (or anyone) puts **gas only** on agent address
3. Ship `FleetStrike` script under agent key: scan → sim → flash liq → Cake
4. First profitable fire = repayment toward lost gas; surplus stays Cake

## Confirm
Reply **GO 1** (Strike watcher), **GO 1+2**, or **GO 4** (arb cron). Nothing fires until that word.
