# Bootstrap First $500k — Working With The Rails

**No broadcast without King GO + named flag.**  
DeFi starts thin. Here’s how Kingdom rails actually open the first $500k — mapped to live Base state.

---

## Live report (now)

| Metric | Value |
|--|--|
| **Free Elepan (hot)** | **34,576,753.98** |
| **CDP coll** | **25,200,000** Elepan |
| **HF** | **1.9384** |
| **CDP max withdraw (HF-safe)** | **~5,049,807** Elepan |
| **CDP mint headroom** | **~3.26M eUSD** → Landing |
| **Landing eUSD** | **13.0M** (already minted) |
| **ZK `isProven(hot)`** | **true** · threshold **$700k** |
| **yELEPAN-USDC** | **~$14.0M** (King-owned magnet @ ~100% util) |
| **ZK credit USDC balance** | **$0** (rail live, unfunded) |

Surface for bootstrap: free + withdrawable ≈ **39.6M Elepan** still movable without cracking HF.

---

## Your four tactics → what lands $500k

### 1) Flash seed from Morpho inventory — USE IT RIGHT
**Works for Morpho magnet (already fired):** flash USDC → yELEPAN → borrow repay. That’s why the vault is ~$14M and rate is maxed — classic thin→fat Morpho bootstrap.

**DEX pair seed (Elepan/USDC):** flash cannot *leave* USDC in a pool and repay in the same tx. Real sequence:
1. Get **permanent** $500k USDC (tactic 4 / credit below)  
2. Create Elepan/USDC pool  
3. Seed both sides (free Elepan + that USDC)  
4. Optional: Morpho flash only to *size* books you can close atomically  

Flash builds **your credit market**. Permanent USDC builds **the DEX**.

### 2) Merkle / point incentives — OWN EMITTER (no Merkl wait)
Point **Elepan** from the free 34.6M bag at **yELEPAN-USDC** depositors (Kingdom distributor, not Angle whitelist).  
High Morpho borrow APY at full util + Elepan emissions = the Morpho-standard LP magnet.  
This grows external idle so King can `borrow → Landing`. Not a same-block $500k guarantee — it is the scale engine after the first chip.

### 3) Self-loop Elepan → eUSD — REAL MINT, THEN CLEAR
CDP can mint **~3.26M more eUSD** to Landing at current HF, or use the **13M already there**.  
Loop “eUSD → buy coll / seed pool” needs a **clear** (OTC or pool). Public DEX clear for Kingdom eUSD = **not live yet**.  
So: mint is ready; clear = tactic 4 or pool after first USDC.

### 4) ZK attestation → private advance — **TODAY’s $500k door**
Rails are already green:
- Gate `0xca2a…3f30` · `isProven(hot)=true` · threshold $700k  
- Credit `0xc415…d936` · draw-to-Landing design · **≤70% × $700k = $490k** capacity when funded  
- Proof tx `0xe5630deb…771d88`

**$500k test (two flavors, both real):**

| Flavor | Action |
|--|--|
| **A. Credit rail** | Counterparty `deposit` **500k USDC** into `CrownZkElepanCredit` → King `draw` **500k → Landing** |
| **B. Direct escrow** | Counterparty wires **500k USDC** to Landing against the attestation packet (below) |

No public pool required. This is what the ZK rail was built for.

---

## Attestation packet (hand to 1–2 trusted parties)

```
Subject:     0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
Gate:        0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30
Credit:      0xc4152c73824d85146B0f85a0b77E911D4769d936
Proof tx:    0xe5630deb4889ad574c64feeb9ac884dad2857125894ecfc3f956515d11771d88
Threshold:   $700,000 (attested)
Draw cap:    $490,000 (70%)
Ask (test):  $500,000 USDC → Landing 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
CDP:         25.2M Elepan coll · 13M eUSD debt · HF 1.938
Free Elepan: 34.58M
yELEPAN:     ~$14M TVL (King curator)
```

---

## First $500k sequence (thin → live)

| Step | Flag | What |
|--|--|--|
| T0 | — | King names counterparty (credit deposit or wire) |
| T1 | `FIRE_ZK_CREDIT=1` | On 500k credited: draw 500k USDC → Landing |
| T2 | `FIRE_POOL=1` | Seed Elepan/USDC DEX with slice of that 500k + free Elepan |
| T3 | `FIRE_EMIT=1` | Kingdom Merkle/stream Elepan rewards → yELEPAN |
| T4 | `FIRE_BORROW=1` | When external idle appears on Morpho: borrow more → Landing |

T0/T1 = **cash today**. T2–T4 = growth. CDP partial withdraw adds Elepan surface for T2/coll — optional, HF stays ≥ 1.55.

---

## One-line

> Free **34.58M Elepan**, HF **1.94**, ZK **proven $700k** — fund the credit rail or wire against the attestation for **$500k to Landing**, then seed the pair and emit into the vault you already filled.
