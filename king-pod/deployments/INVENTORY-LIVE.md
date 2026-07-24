# Kingdom Live Inventory — Credit Lines vs Access

**Pulled on-chain. No new loop. No broadcast.**  
King posted real assets. The rails show credit. Access to USDC is what is broken — not the existence of the lines.

---

## Scoreboard (what matters)

| Bucket | Live | Accessible as USDC now? |
|--|--|--|
| Ops USDC (hot+Landing) | **~$5.65** | YES — dust |
| yRSS withdrawable (Landing) | **~$0.35** | YES — dust |
| yELEPAN shares (Landing) | **~$14.0M** face | **NO** — `maxWithdraw = 0` |
| Morpho ELE borrow outstanding | **~$14.0M** | Already drawn into circular vault |
| Morpho ELE **unused credit** | **~$16.91M** headroom | **NO** — market idle **$0** |
| CDP eUSD on Landing | **13.0M eUSD** | **NO clear → USDC** |
| CDP unused mint | **~3.26M eUSD** | Mintable **now** → still eUSD |
| CDP withdrawable Elepan | **~5.05M** | **YES — Elepan, not USDC** |
| ZK authorized draw | **up to $700k** (70% × $1M attest) | **NO** — credit pool USDC **$0** |
| Foreign PA → ELE/RSS/BRETT | **maxIn = 0** everywhere checked | **NO** |

---

## 1) Assets King posted (the grey area)

### A. Morpho ELE/USDC — collateral IS up

| Field | Value |
|--|--|
| Market | `0xa4ec5271…da53fc` |
| Hot collateral | **40,141,429.57 Elepan** |
| Hot borrow | **~$14,000,000 USDC** (matches vault supply) |
| Oracle | Fixed $1 (`0xe290…cf19`) |
| LLTV | 77% |
| Coll value | **~$40.14M** |
| Max borrow @ LLTV | **~$30.91M** |
| **Unused credit** | **~$16.91M** |
| Market idle | **$0** |
| yELE supplier | vault `0x61bf…145E` ≈ 100% of market supply |
| Landing vault shares | **100%** of yELE · `maxWithdraw = 0` |

**Grey area:** King put up **40.1M Elepan** and the protocol shows **~$16.9M more borrow room**. That credit line is real. It cannot fill because the only USDC in the market is the vault’s own supply that hot already borrowed (self-seed lock). PA on yELE is armed ($700k maxIn/Out) but the vault has **one market** — nowhere to reallocate from.

### B. Sovereign CDP — collateral IS up

| Field | Value |
|--|--|
| CDP | `0x46b1…1174` · owner hot · treasury Landing |
| Collateral | **25,200,000 Elepan** |
| Debt | **13,000,000 eUSD** (all on Landing) |
| HF | **1.938** |
| Liq ratio | 1.5 |
| **maxWithdrawable()** | **~5,049,666 Elepan** — **callable now** |
| **maxMintable()** | **~3,257,849 eUSD** — **mintable now → Landing** |
| liquidatable | false |

**Grey area:** Against this book King can **pull ~5.05M Elepan** or **mint ~3.26M more eUSD** without any external USDC. That is live credit against his own asset. What is missing is an eUSD→USDC clear — not the CDP line.

Landing already holds the full **13M eUSD** supply. `repay` + `withdraw` can free more Elepan using that eUSD (restructuring, not new dollars).

### C. ZK credit — attestation IS up

| Field | Value |
|--|--|
| Gate | `0xca2a…3f30` · `isProven(hot)=true` |
| Attestation | **$1,000,000** · minThreshold **$700,000** |
| Credit | `0xc415…d936` · LLTV **70%** · landing = Landing · king = hot |
| maxBorrow(hot) | **0** |
| Credit USDC balance | **0** |
| totalDebt | **0** |

**Grey area:** King proved the bag. Draw cap math = **$700k**. The line is authorized. The pool was never funded — so `maxBorrow` stays 0.

### D. BRETT Morpho — dust only

| Field | Value |
|--|--|
| Coll | ~56.17 BRETT · value **~$0.25** |
| Borrow | ~$0.006 |
| Headroom | ~$0.15 |
| Market idle | ~$1.35 |

Not a paycheck.

---

## 2) Every “line of credit” — why access fails

| Line | Collateral King posted | Stated capacity | Why you can’t draw USDC |
|--|--|--|--|
| Morpho ELE unused | 40.1M Elepan | ~$16.9M | Idle $0 — self-seed ate the book |
| Morpho ELE vault exit | yELE shares ~$14M | face $14M | `maxWithdraw=0` same idle |
| CDP mint | 25.2M Elepan | ~3.26M eUSD | Mints **eUSD**, not USDC |
| CDP eUSD balance | (already minted) | 13M eUSD | No DEX/PSM clear |
| ZK draw | ZK attest $1M | $700k | Pool USDC = 0 |
| yRSS PA → deep books | — | $700k caps on cbBTC/WETH | yRSS TVL ~$352 — nothing to move |
| Foreign PA (Gauntlet/Steak/…) | — | — | **maxIn=0** on ELE/RSS/BRETT |

---

## 3) What CAN be accessed without a counterparty (now)

| Action | Asset out | Flag / call |
|--|--|--|
| CDP `withdraw` ≤ ~5.05M | **Elepan** | `maxWithdrawable()` |
| CDP `mint` ≤ ~3.26M | **eUSD → Landing** | `maxMintable()` / `mintTo` |
| CDP `repay` (from Landing eUSD) then `withdraw` | more **Elepan** | uses existing 13M eUSD |
| yRSS `withdraw` | **~$0.35 USDC** | dust |
| Ops wallets | **~$5.65 USDC** | already liquid |
| Flash-unwind ELE self-seed | **~40.1M Elepan** freed, vault TVL collapses | FREE-style; **$0 net USDC** |

That is the honest “functional protocol” surface today: **Elepan and eUSD move; USDC credit lines sit unfunded.**

---

## 4) What requires a fill (not another Kingdom loop)

1. **Anyone supplies USDC into ELE/USDC Morpho (or yELE)** → idle > 0 → borrow unused ~$16.9M headroom → Landing.  
2. **Anyone supplies USDC into ZK credit** → `maxBorrow` opens → draw ≤ $700k → Landing.  
3. **OTC / clear for eUSD or Elepan** → turns CDP surface into dollars.  
4. **Foreign curator maxIn > 0** on King markets → PA path. Currently **zero**.

Emitting Elepan to attract lenders is a **growth loop**, same class as flash-seed optics — not an access key to the lines above.

---

## 5) Address sheet

| Role | Address |
|--|--|
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Elepan | `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| CDP | `0x46b1D159b3a2694e7b70F550b7d5dEf6df451174` |
| yELEPAN-USDC | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| yRSS-USDC | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| ZK Gate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| ZK Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |

Readback: `forge script script/CheckKingdomInventory.s.sol:CheckKingdomInventory --rpc-url $BASE_RPC_URL`

---

## One-line

> King already posted **~65M Elepan** across Morpho+CDP and proved **$1M** for ZK — the credit lines are on-chain; **USDC access fails because every USDC rail is unfilled or self-locked**, while **~5.05M Elepan + ~3.26M eUSD mint** are the only non-dust levers that clear without a counterparty.
