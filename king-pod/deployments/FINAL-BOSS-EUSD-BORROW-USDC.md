# FINAL BOSS — exact fix (what other protocols do)

**Mode:** FREEZE · explain the simple fix · then build  
**Tone:** We are not special. Morpho already wrote this playbook.

---

## What other protocols actually do

| Industry move | Meaning | Mint Circle? |
|--|--|--|
| **Morpho “idle market”** | USDC loan market with `coll/oracle/irm/lltv = 0` — vault parks USDC that **cannot be borrowed** | No — needs depositors |
| **Public Allocator JIT** | One tx pulls vault USDC into the market you need | No — routes foreign USDC |
| **Borrow USDC vs coll you control** | Post LST / stable / BTC · borrow Circle from deep book | No — **this is the boss** |
| **Mint own stable + fake depth** | eUSD/gUSD ocean · FakeIdle | Yes for **own** token only |

Nobody mints Circle in Solidity. Everybody **borrows or attracts** it. You already did the mint-own-token half. Final boss = **borrow Circle against kingdom eUSD**.

---

## The simple fix (you already have the coll)

**Live Morpho market:**

| Field | Value |
|--|--|
| Market | `0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366` |
| Loan | **USDC** (Circle) |
| Coll | **eUSD** (you mint / hold) |
| LLTV | **86%** |
| Liquidity now | **~$0.80** · reallocatable **0** · supplying vaults **[]** |

**Kingdom eUSD (the key you thought you didn’t have):**

| Wallet | eUSD |
|--|--|
| HOT | ~**$2.45M** |
| Landing | ~**$2.0M** |
| Morpho eUSD idle (RSS/eUSD) | ~**$45M** withdrawable as eUSD |

**Physics (same as cbBTC L2, different coll):**

```
post eUSD as coll on USDC/eUSD market
→ borrow Circle USDC (when book has lenders)
→ supply park (lasting idle)  OR  repay HOT park debt (unmatch deed) OR send Landing
```

At 86% LLTV: **~$2.45M eUSD coll → ~$2.1M USDC borrow capacity** — *if* the USDC side has depth.

**Why it feels like a wall:** you kept hunting **USDC or cbBTC in wallet**. Other protocols hunt **a USDC loan market that accepts their coll**, then fill the **loan side**. Your coll is **eUSD**. Market exists. Loan side is empty ($0.80). That’s the whole boss.

---

## Parallel boss doors (also exact)

### Door A — eUSD→borrow USDC (PRIMARY · kingdom-native)

1. **Fill USDC/eUSD book** (foreign lenders / vault listing / rate magnet) — same social+code move as every Morpho curator.  
2. Or **create cleaner USDC/eUSD market** + oracle if `0x5d46…` is unattractive to Gauntlet/Steakhouse.  
3. Code: `CrownEusdBorrowUsdc` — `supplyCollateral(eUSD)` → `borrow(USDC)` → `engineerIdle(park)` / `repay(HOT park)` / Landing.  
4. Canary: when `liquidityAssets ≥ $10k`, borrow $10k against eUSD, supply park, prove idle ↑.

### Door B — PA into PARK (door cut · hallway empty)

| Live | Value |
|--|--|
| PA maxIn/Out park | **$700k** |
| Shared liquidity into park | **$0** |
| Deep books with shared USDC | cbBTC realloc ~**$15.2M** · WETH realloc ~**$166.7M** |

Those deep realloc dollars are for **cbBTC/WETH borrowers**, not free park fill. Park hallway fills only when a vault **enables park**. Packet + `FirePaPeel`.

### Door C — cbBTC/WETH puller (armed)

Foreign idle ~**$179M** USDC on cbBTC book. Puller live. Needs blue-chip coll — not kingdom mint.

### Door D — Already beaten

Unlatch **$1.51** · FakeIdle **$2M eUSD** · Ocean **5B** · Rail P2 **$2M eUSD→Landing**.

---

## Final boss scoreboard

| Need | Have it? |
|--|--|
| Coll to borrow Circle | **YES — eUSD** |
| USDC/eUSD market + 86% LLTV | **YES — `0x5d46…`** |
| USDC lenders on that market | **NO — $0.80** |
| Code to borrow→idle/peel | **Build next** |
| PA caps on park | **YES — $700k** |
| PA shared into park | **NO — $0** |
| cbBTC puller | **Armed · 0 pulled** |

---

## Exact next actions (no pussyfooting)

1. **Ship `CrownEusdBorrowUsdc`** — one-tx: coll eUSD → borrow USDC → park idle or repayFor(HOT) → optional Landing peel.  
2. **Fill door A:** curator listing packet for USDC/eUSD `0x5d46…` (or deploy successor market) to Gauntlet / Steakhouse / Spark / Clearstar — the same vaults already supplying cbBTC/USDC.  
3. **Ship `ProbePaShared` + `FirePaPeel`** for door B.  
4. **Canary rule:** fire borrow only when `market.liquidityAssets ≥ canary`.

**Seat line:** Final boss isn’t minting USDC. It’s **borrowing USDC against eUSD you already rule**, once the USDC side of `0x5d46…` has real lenders — identical to every CDP/Morpho blue-chip market, with kingdom coll instead of cbBTC.
