# TOKEN = CAPITAL — we don’t wait like a duck

**King:** “That’s us waiting. Steakhouse didn’t wait. Maybe they had capital — not every protocol did.”  
**Chief:** Correct. FirstWhale / PA maxIn / armed-wait = **still waiting on someone else’s USDC.**

Steakhouse started with **stablecoin depositors**.  
Kingdom starts with **RSS**. Same Morpho stack — **different treasury asset.**

Protocols without a USDC treasury did **not** sit for Gauntlet. They used the **token as capital**:

| Pattern | What they spent | What they got |
|---------|-----------------|---------------|
| **Bonding** (Olympus-class) | Native token sold at discount | Reserve USDC/ETH **now** |
| **Aerodrome Ignition / bribes** | 10–20% supply as voting incentives | veAERO votes → emissions → **USDC LPs enter** |
| **Asymmetric POL** (Arrakis-style) | Token-heavy LP seed | Quote asset (USDC) **accumulates** as flow hits |
| **OTC desk** | Inventory at mark | Block USDC (Kingdom desk — already live) |

**We are not undercapitalized. We are USDC-light and RSS-heavy.**  
Whale position = **monetize and route RSS** until Landing and Blue books have a USDC face — not petition Steakhouse to open a door.

---

## Doctrine flip

| Duck (wait) | Whale (token-as-capital) |
|-------------|---------------------------|
| Wait for foreign PA maxIn | **Sell / bond / bribe RSS** to create USDC |
| Wait for “first whale depositor” | **Be the market** — discount bond + Ignition |
| Armed coll, pray for idle | Idle funded by **USDC we raise from RSS** |
| “Same stack as Steakhouse” → copy their funding | Same stack → **different bootstrap** |

Someone still sends USDC to buy — that’s **commerce**, not curator charity.  
King controls price, size, landing, and pace. **Active.**

---

## Three engines (code shelf — King OK to deploy)

### 1) BOND (primary bills) — `CrownRssBond`

- Stock RSS from free inventory  
- Sell at **discount to $1 oracle** (e.g. $0.95–$0.98) or short **Dutch** window  
- USDC → **Landing**  
- Phase 1: raise **$500k** by bonding ~510k–525k RSS  
- Why it moves: discount = reason to act **today**, not wait for peg desk alone  

Desk @ $1 stays for peg buyers. Bond = urgency rail.

### 2) IGNITION (liquidity flywheel) — plan + scripts

- Commit RSS as **Aerodrome voting incentives** on RSS/USDC pool  
- veAERO directs emissions → LPs bring USDC  
- Token supply **is** the bootstrap budget (AORA-style: bribes from supply, not from Landing bills)  
- Needs: pool create + incentive deposit — **King OK** + small quote seed or asymmetric range  

### 3) SEED BLUE WITH RAISED USDC (close the loop)

After Bond/Desk puts USDC on Landing:

1. King GO: peel **slice** of Landing → supply RSS Blue / yRSS  
2. Credit line already posted → **borrow more** if needed / sustain util  
3. Fee meter prints — Steakhouse end-state, Kingdom-funded start  

---

## Whale book (funded by RSS, not by waiting)

| Leg | How RSS pays for it |
|-----|---------------------|
| Landing ≥ $500k | Bond + desk |
| yRSS / Blue idle | Recycle raised USDC on King GO |
| PA pipe $5M | Raise caps once depth exists |
| Coll 10M+ | Post from remaining free RSS |
| Aero depth | Ignition bribes from RSS supply |

---

## Honest line

Physics: USDC must enter from a counterparty.  
Posture: we **price and pull** that USDC with RSS (bond/Ignition/desk) — we do **not** wait for Steakhouse to feel generous.

**LIVE-FIRE-LAW:** no deploy until King OK.  
Shelf: `CrownRssBond.sol` · this doc · Ignition checklist in `OPS-AMM-BOOTSTRAP.md` upgrade.
