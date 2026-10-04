# VERIFY — cbBTC / USDC Morpho idle (Phase 1 only)

**Mode:** VERIFY · paper + live reads · **no fire**  
**Chain:** Base · **chainId `8453`** · block **52173831**  
**Law:** Phase 2 / 3 DENIED until this record stands and Ocean reconciliation is accepted  
**AMO 6 gate (live):** armed **true** · tripped **false** · amoCount **4** · MintGate.canMint **false** · ColdBuffer **minBufferBps = 3000**

---

## 1) Exact market identity

This is a **Morpho Blue market id** (bytes32), not a standalone ERC4626. Liquidity lives on the Morpho singleton.

| Field | Value |
|--|--|
| **Market id** | `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836` |
| **Morpho Blue** | [`0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`](https://basescan.org/address/0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb) (verified singleton) |
| Loan token | USDC [`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`](https://basescan.org/token/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913) |
| Collateral | cbBTC [`0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf`](https://basescan.org/token/0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf) |
| Oracle | [`0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9`](https://basescan.org/address/0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9) |
| IRM | AdaptiveCurve [`0x46415998764C29aB2a25CbeA6254146D50D22687`](https://basescan.org/address/0x46415998764C29aB2a25CbeA6254146D50D22687) |
| LLTV | **86%** (`860000000000000000`) |
| Morpho app | [market `0x9103…1836`](https://app.morpho.org/base/market/0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836) |

`cast call Morpho.idToMarketParams(0x9103…1836)` confirmed the five-tuple above.

---

## 2) Live idle read (the “$166M”)

`Morpho.market(0x9103…1836)` at block **52173831**:

| Field | Raw (USDC 6dp) | USD |
|--|--:|--:|
| totalSupplyAssets | `1685023244468546` | **$1,685,023,244.47** |
| totalBorrowAssets | `1517238166200245` | **$1,517,238,166.20** |
| **idle (= supply − borrow)** | **`167785078268301`** | **$167,785,078.27** |
| fee | `0` | — |

**Verdict:** The idle is **real and present** — about **$167.8M USDC** borrowable liquidity in this market (not “$166M cbBTC in a vault”). Prior “$166M” was the right order of magnitude; this read pins it.

---

## 3) yRSS permission trace (honest)

**yRSS** [`0xF80C0529bD94C773844E459853CD91B9263dD525`](https://basescan.org/address/0xF80C0529bD94C773844E459853CD91B9263dD525)

| Check | Live read |
|--|--|
| Market enabled on yRSS | **true** · supply cap **$14,000,000** (`config(0x9103…)`) |
| On supplyQueue | **yes** · index **4** |
| On withdrawQueue | **yes** · index **1** |
| PA isAllocator | **true** |
| PA flowCaps (yRSS ↔ this market) | maxIn **$2,000,000** · maxOut **$2,000,000** |
| **yRSS Morpho position** | supplyShares **0** · borrowShares **0** · collateral **0** |

**Permission truth:** yRSS *may* allocate into / withdraw from this market **only for inventory it holds**. It currently holds **nothing** here. It cannot `withdraw` the $167.8M idle — that USDC is other suppliers’ cash, available to **borrowers who post cbBTC**, or to a **Public Allocator reallocation** from a vault that actually has maxOut liquidity here (foreign curators), not by a naked yRSS pull.

HOT cbBTC balance: **257** wei — not meaningful borrow collateral.

---

## 4) Governance read

| Role | Address | Note |
|--|--|--|
| yRSS owner | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` (**HOT**) | King |
| yRSS curator | **HOT** | King |
| yRSS guardian | `0x0` | none |
| yRSS timelock | **0** | no delay on curator ops |
| Allocator HOT | **true** | |
| Allocator PA `0xA090…0467` | **true** | |
| PA admin(yRSS) | **HOT** | King sets flowCaps |

**Verdict:** King-controlled vault governance is **proven** (owner/curator/PA admin = HOT, timelock 0, no guardian). That does **not** equal custody of the $167.8M idle.

---

## 5) Conversion path (cbBTC idle → Ocean legs)

**Physics:** Market idle is **USDC**, loan-side. It is not a bag of cbBTC to swap into USDT/DAI/EURC.

| Step | Mechanism | Seeds |
|--|--|--|
| A | Post **real cbBTC** → `Morpho.borrow` USDC from this idle | HOT USDC |
| B | Foreign vault PA `reallocateTo` into King RSS / yRSS (needs their maxIn) | yRSS / RSS book USDC |
| C | HOT USDC → Spoils / DeepPull Ocean **USDC** leg (already the sealed first external leg) | Ocean USDC |
| D | USDT · DAI · EURC Ocean legs | **Separate inventory + venues** — USDC from A/B/C does not auto-mint those legs |

**Reconciliation with Ocean law:** Even a full reclaim of USDC idle only funds the **USDC** external leg (and Cold/HOT split). Widening to USDT/DAI/EURC still requires those assets and pools — per `SEALED-OCEAN-EXTERNAL-LEGS.md`. No AMO against self-paired Ocean alone. AMO 6 remains the gate before any Ocean widen fire.

---

## Phase status

| Phase | Status |
|--|--|
| **1 Verification** | **DONE** — this file |
| 2 Access / reclaim design | **DENIED** until King accepts this record + Ocean reconcile |
| 3 Fire | **DENIED** — sealed gates + Phase 1 acceptance |

```
VERIFY_CBBTC_IDLE=1
CHAIN=8453
MARKET=0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836
IDLE_USDC=167785078268301
YRSS_POSITION=0
GOVERNANCE=HOT_timelock0
AMO6=GREEN
PHASE2=DENIED
NEXT=King_accepts_record→then_sequence_vs_Ocean
```
