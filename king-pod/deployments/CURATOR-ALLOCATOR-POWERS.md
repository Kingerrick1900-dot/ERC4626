# CURATOR / ALLOCATOR — full power check (customize in our favor)

**Mode:** FREEZE · audit first · no broadcast  
**Vault:** yRSS `0xF80C0529bD94C773844E459853CD91B9263dD525`  
**Signer:** HOT owns **owner + curator + allocator + PA admin** · **timelock = 0** (instant)

---

## 1) Roles (live)

| Role | Address | Notes |
|--|--|--|
| **owner** | HOT `0x6708…a7d1` | Full MetaMorpho control |
| **curator** | HOT | Caps, queues, enable markets |
| **allocator** | HOT **true** · Landing **false** · PA **true** | Instant `reallocate` |
| **guardian** | `address(0)` | No guardian brake |
| **timelock** | **0** | Cap/queue changes apply **now** |
| **fee** | **10%** → Landing | Performance fee already kingdom |
| **skimRecipient** | HOT | |
| **PA admin** | HOT | `setFlowCaps` / `setFee` on PA |

**Verdict:** Max control. Nothing blocked by timelock or foreign curator. Customize freely.

---

## 2) Markets already enabled (the favor already baked in)

| Market | Cap | In supply Q | yRSS supply | PA maxIn / maxOut | Role |
|--|--|--|--|--|--|
| **Park** USDC/RSS `0x41c0…` | **$14M** | SQ0 **first** | ~all TVL | **$700k / $700k** | Deed / latch book |
| RSS40 `0x40ac…` | $14M | SQ1 | dust | $700k / $700k | Classic PoD |
| **cbBTC/USDC** `0x9103…` | $14M | SQ2 | **0** | **0 / $700k** | Deep foreign book — maxIn **0** (cannot PA *into* here from yRSS) |
| **WETH/USDC** `0x8793…` | $14M | SQ3 | **0** | **0 / $700k** | Same — maxIn 0 |
| BRETT/USDC `0xf6f4…` | $2M | SQ4 | dust | ~$700k | Moat |
| RSS alt `0x3a5b…` | $14M | WQ only | 0 | $700k / $700k | Enabled, not fed |
| RSS `0xa4ec…` (elephanToken) | $14M | WQ only | small | ~$28.7M / $28.7M | Partial alloc |
| **eUSD/USDC `0x5d46…`** | **$50M** | **WQ only · NOT in supply Q** | **0** | **$50M / $50M** | ★ Final-boss coll book — **already curated hard** |

**Canonical Base USDC idle market** (coll=0): `0x38c846…` · ~**$529k** sitting idle industry-wide · **not enabled on yRSS**.

---

## 3) What we can customize NOW (HOT, one txs)

### A — Supply queue (highest leverage)

**Now:** SQ0 = park → all new deposits hit the **latched** 100% util book.  
**Favor:** Put **eUSD/USDC `0x5d46…` first** (or second after a true idle market):

```
setSupplyQueue([
  eUSD/USDC 0x5d46…,   // NEW USDC → market we borrow against with eUSD
  idle USDC 0x38c8…,   // optional withdraw buffer (enable first)
  park 0x41c0…,
  ...
])
```

**Effect:** Next depositor USDC becomes **borrowable Circle against kingdom eUSD** — curator gravity, not wallet seed.

### B — Enable + cap Morpho idle market

```
submitCap / acceptCap (timelock 0): idle market 0x38c846… cap = max
setSupplyQueue include idle
PA setFlowCaps(idle, maxIn, maxOut) large
```

**Effect:** Standard Morpho curator pattern — vault can hold unmatched USDC buffer; PA can park/pull. Does not mint USDC; structures inbound.

### C — PA flow caps (asymmetric favor)

| Change | Why |
|--|--|
| Park **maxIn → $2M–$5M** (from $700k) | Bigger hallway when foreign vaults enable park |
| cbBTC/WETH **maxIn → $1M+** (from **0**) | Let yRSS *receive* reallocations into deep books if useful; keep maxOut gated |
| eUSD/USDC | Already **$50M / $50M** — leave or mirror on idle |

### D — Allocator reallocate (when liquidity exists)

HOT can `reallocate` yRSS between enabled markets **without PA** when source has withdrawable idle.  
**Block today:** park ~100% util → cannot pull vault USDC out of park into eUSD/USDC.  
**Unblock:** PA inbound, repay, or new deposits via new supply queue order.

### E — Dual allocator

`setIsAllocator(Landing, true)` — Landing can reallocate/ops without sharing HOT key (after rotation).

### F — Fee / magnet

Fee already 10% → Landing. Optional: advertise high borrow APY on eUSD/USDC (IRM is Morpho adaptive — util drives rate). Empty book stays quiet until supply appears.

### G — CreateMarket (if `0x5d46…` stays orphan)

HOT already created BRETT market historically. Can deploy alternate USDC/eUSD market + oracle if listings reject current oracle `0x44bc…`. Then `submitCap` + queue + PA caps — same moat play as BRETT.

---

## 4) What curator power does NOT do

| Wish | Reality |
|--|--|
| Mint Circle into yRSS | Impossible |
| Withdraw park USDC at 100% util | Need idle first |
| PA pull from Gauntlet without them enabling park/eUSD market | Their curator, not ours |
| Force shared liquidity onto park | Packet / incentives |

---

## 5) Recommended customize pack (order)

| # | Tx | Favor |
|--|--|--|
| 1 | `submitCap`+accept **idle** `0x38c846…` (or create if prefer own) | Vault buffer pattern |
| 2 | `setSupplyQueue`: **eUSD/USDC → idle → park → …** | New USDC feeds boss market |
| 3 | `PA.setFlowCaps` park maxIn **$2M+**; cbBTC/WETH maxIn **>$0** | Widen JIT doors |
| 4 | `setIsAllocator(Landing, true)` | Ops redundancy |
| 5 | Keep eUSD/USDC cap **$50M** + PA **$50M** | Already correct |
| 6 | Listing packet: “yRSS routes USDC into eUSD/USDC `0x5d46…`” | Foreign depositors = our borrow fuel |

Then code **CrownEusdBorrowUsdc** fires when `0x5d46…` liquidity ≥ canary.

---

## 6) Seat line

Curator/allocator are **not underused on paper** — eUSD/USDC is already **enabled, $50M cap, $50M PA caps**.  
They **are underused in routing**: supply queue still feeds **park first**, so inbound USDC never reaches the market where **eUSD is the key**.  

**Simple customize:** flip the queue. That is the proper potential.
