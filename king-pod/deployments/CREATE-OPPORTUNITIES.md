# CREATE OPPORTUNITIES — Solo King doctrine

**STATUS: PLAN ONLY — King must read this before any live fire.**  
See `LIVE-FIRE-LAW.md` → **King reads first**. No `--broadcast` until King says OK / GO / FIRE on **this** plan.

**Locked:**
- No “bring capital”
- No “someone” (buyer / lender / curator beg)
- No waiting for Morpho RSS pool to fill
- **Create the opportunity** — then capture when it pays

King has: **~16.7M RSS** · **~$6.52 USDC** · Morpho stack · yRSS · Base.

---

## Doctrine

| Dead talk | Create talk |
|-----------|-------------|
| Bring USDC | **RSS is the budget** |
| Find a buyer | **Build the venue + incentive** |
| When pool fills | **Make a book worth facing** |
| Beg Gauntlet | **Bribe / rate / gauge — opportunity they chase** |

Physics still holds: **new USDC enters only when activity hits a venue King built.**  
King’s job alone is **build venues + incentives with RSS** — not sit on Morpho capacity.

---

## What “create” means (elite, legal)

1. **Create a market** people can use (DEX + Morpho already partly done)
2. **Create a payoff** for using it (bribes, APY, rebate, discount)
3. **Create demand** on the book (borrow util / LP emissions)
4. **Capture** fees / borrowed idle / LP share when flow hits

King creates **1–3**. Capture **4** is automatic when the opportunity works.

---

## Opportunity engines (RSS-funded — King solo)

### CREATE 1 — Aerodrome RSS/USDC venue (Ignition)

**Build:** Pool that does not exist today.  
**Fuel:** RSS inventory (asymmetric LP) + dust USDC seed from hot (~$6 keeps gas; use only what King OK).  
**Incentive:** RSS as **vote bribes** → veAERO directs emissions → LPs chase APR → **USDC enters the pool as LP capital chasing the opportunity King created.**

Not “please deposit.”  
**“Here is APR paid in RSS / emissions — take it.”**

| Piece | Status |
|-------|--------|
| `FireAeroIgnition.s.sol` | Shelf |
| Pool RSS/USDC | **Does not exist** — create |
| Bribe budget | RSS from hot (King sets %) |

**Creates:** Trade venue + LP opportunity.  
**Capture:** Swap fees + ability to sell RSS into live book + deeper quote.

---

### CREATE 2 — Rate magnet (yRSS util)

**Build:** High borrow util on Kingdom Morpho books → high supply APY on yRSS.  
**Fuel:** Post RSS as collateral (borrow demand signal). Seed book USDC only from **raised** or **fee** paths later — not “bring.”  
**Incentive:** APY number is the opportunity.

| Piece | Status |
|-------|--------|
| yRSS 10% fee | Live |
| RSS77 / RSS91 / BRETT | Live |
| TVL | Dust — magnet needs util story |

**Creates:** Yield product.  
**Capture:** 10% curator fee when TVL + borrows exist.

---

### CREATE 3 — Own-market moat (already proven pattern)

**Build:** Kingdom-created Morpho markets (RSS FixedOracle, BRETT TWAP).  
**Fuel:** RSS / BRETT inventory.  
**Incentive:** Unique collateral niche — Fixed $1 RSS is a **product** no shared Chainlink herd has.

**Creates:** Borrow/lend opportunity only Kingdom hosts.  
**Capture:** Interest + fees when books are used.

---

### CREATE 4 — Gauge / bribe flywheel (token-as-capital)

**Build:** Continuous RSS emissions to Aerodrome gauges.  
**Fuel:** **10–20% of free RSS** as multi-epoch bribe budget (King sets).  
**Incentive:** Voters and LPs optimize for bribe APR — capital follows the opportunity.

Same playbook as protocols that bootstrapped **without a USDC treasury**.

---

## Explicitly dead (do not schedule)

| Path | Why dead under this doctrine |
|------|------------------------------|
| “Bring capital to hot” | Forbidden talk |
| “When RSS Morpho idle fills” | Will not happen by hope |
| Desk/bond wait | No counterparty machine |
| Fortress self-seed | Creates debt, **$0** spendable USDC |
| Beg Gauntlet maxIn | Beg, not create |

---

## Execution order (create first)

| # | Create | King FIRE | Result |
|---|--------|-----------|--------|
| **1** | Create RSS/USDC Aero pool + RSS-heavy LP | `FIRE_IGNITION=1` | Venue exists |
| **2** | Stock RSS bribe budget on gauge | King sets `BRIBE_RSS` | APR opportunity live |
| **3** | Post RSS on Morpho (demand signal only) | `FIRE_RSS=1` | Book shows borrower |
| **4** | Scoreboard: pool TVL, bribe APR, yRSS TVL, Landing USDC | Weekly | Capture when flow hits |

**Cash printer = Create 1+2 working.**  
Morpho post (3) supports the story; it is **not** the payroll alone.

---

## King one-liner

> We do not bring capital and we do not wait for someone.  
> We **create** the venue and the payoff with RSS.  
> USDC that shows up is chasing the opportunity we built.

---

## Next build (scribe — no broadcast until King FIRE)

1. Harden `FireAeroIgnition` — create pool + asymmetric RSS LP + optional bribe deposit  
2. `CREATE-OPPORTUNITIES` scoreboard script  
3. Drop all “bring / someone / when pool fills” from robot primary path  

**King GO:** bribe size (% of RSS) + seed USDC cap from hot ($0 keep all / $1 / $6).
