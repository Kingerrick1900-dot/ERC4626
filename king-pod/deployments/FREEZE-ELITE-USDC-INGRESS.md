# FREEZE — How elites actually get USDC into the system

**Honest kill:** The PARK knot unwind is **not** an elite USDC-ingress path. It closes a self-loan. Prefund ~$9k does **not** leave yRSS with $1M+ idle. That plan does not put Circle in the treasury.

**Question answered:** How did protocols in the **same seat** (mint their own dollar, thin/no Circle inventory) get USDC/DAI/USDT **into** the protocol?

---

## The only patterns that work

### 1) Peg Stability Module / GSM — **primary elite door**

| Protocol | Mechanism |
|--|--|
| **Maker / Sky** | `sellGem`: user sends **USDC** → protocol **mints DAI** 1:1. USDC sits in the PSM vault as **protocol-owned** collateral. |
| **Aave GHO** | **GSM**: user deposits USDC/USDT → receives GHO; USDC accumulates in the GSM reserve. |
| **Ethena** | Whitelisted mint: user sends **USDC/USDT** → mint USDe; collateral routes to custody. Later L2 PSM same idea. |

**Law:** Foreign stable enters because a **counterparty brings it** to buy/mint your dollar. Code opens the door + sets fees/caps. Code does **not** invent Circle.

**Kingdom map:** HOT already owns Base multi-PSM `0xF733…`. Live USDC in it = **$0**. PowerRail `ingestStable` is the same door. Empty until someone `sellGem` / ingest.

---

### 2) Seed collateral first, then AMO (Frax)

Frax did **not** mint USDC. It started with **USDC collateral in the pool**, then AMOs minted **FRAX** beside that USDC into Curve, lending, etc.

**Law:** AMO spends **existing** foreign collateral + **minted own stable**. No USDC in → no USDC AMO out.

**Kingdom map:** Ocean is eUSD/gUSD (both kingdom). That is mint–mint depth, not a USDC AMO. USDC AMO needs a USDC seed (PSM fill, raise, or OTC).

---

### 3) Users borrow your stable vs their coll (GHO / Maker CDP)

Users post ETH/LST/RWA → mint/borrow **your** dollar. Protocol gains **fees**, not USDC—unless liquidations sell coll for stables later.

**Kingdom map:** PowerRail `mintSupplyLoan` (eUSD loan books) = this lineage. Grows **eUSD** utility. Does **not** deposit USDC into Landing by itself.

---

### 4) OTC / MM / raise / RWA coupons

Sky RWA, Ethena custody routes, every launch: **named buyers** wire USDC for tokens or equity. Off-chain counterparty, on-chain settle.

**Kingdom map:** Still a real door. Not a Morpho flash.

---

### 5) What elites never did

| Fantasy | Reality |
|--|--|
| Flash-unwind own self-seed → “treasury USDC” | Conserves cash; clears debt |
| `createMarket` → borrow $1M USDC from empty book | Loan idle required |
| Mint own stable and call it Circle | Peg asset ≠ USDC |
| Wait on foreign Morpho idle as “the plan” | Passive if filled; not ingress |

---

## Kingdom position (same as early Maker)

| Have | Elite equivalent |
|--|--|
| Mint eUSD | Mint DAI / GHO / USDe |
| PSM / ingest door (empty) | Maker PSM before first `sellGem` |
| eUSD/gUSD ocean | FRAX/own-stable LP without USDC leg |
| Morpho eUSD-coll books empty | Pre-fill borrow books |

**USDC enters when:** arb/MM/user prefers eUSD and pays USDC into PSM/ingest — **or** King names an OTC wire — **or** a USDC seed arrives and AMO/Morpho supply uses it.

---

## Plan (freeze · no fire · no knot theater)

1. **Treat PSM/ingest as the ingress product** — fee `tin/tout`, size caps, Landing/sweep of gem, public arb route (Maker playbook).  
2. **Stop selling knot-unwind as USDC print.** Optional later as RSS-free hygiene only.  
3. **Mint eUSD utility in parallel** (loan books / payroll in eUSD) so counterparties have a reason to sell USDC for eUSD.  
4. **If Circle needed day-one:** name MM/OTC size — every elite did this once; code cannot replace it.

---

## One-block

```
ELITE USDC IN = PSM/GSM/mint-against-USDC (counterparty brings Circle)
NOT = flash self-seed unwind · empty Morpho borrow · mint eUSD≠USDC
KING = mint eUSD + empty PSM · fill door or name OTC · then AMO
```
