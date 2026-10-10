# VERIFY — cbBTC / USDC Morpho idle (Proof Set A)

**Mode:** VERIFY · paper + live reads · **no fire**  
**Chain:** Base · **chainId `8453`** · block **52194988** (identity/params/position) · idle arithmetic confirmed again @ **52195008**  
**Law:** Phase 2 / 3 DENIED until this record stands. Engineering gated with AMO6 proof + Step 1 audit.  
**AMO 6 (companion live @ 52194988):** armed **true** · tripped **false** · amoCount **4** · MintGate.canMint **false** · ColdBuffer **minBufferBps = 3000** — full tx proof in `PROOF-AMO6-GREEN.md`

---

## 1) Exact market identity (full address — not truncated)

This is a **Morpho Blue market id** (bytes32), not a standalone ERC4626. Liquidity lives on the Morpho singleton.

| Field | Full value |
|--|--|
| **Market id** | `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836` |
| **Morpho Blue** | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| **Loan token (USDC)** | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| **Collateral (cbBTC)** | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` |
| **Oracle** | `0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9` |
| **IRM** | `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| **LLTV** | `860000000000000000` = **86%** |

`cast call Morpho.idToMarketParams(0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836)` @ block **52194988** confirmed the five-tuple above.

Morpho app: https://app.morpho.org/base/market/0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836

---

## 2) Live idle read — block, caller, raw return

**Caller:** public `cast call` (read-only)  
**Target:** `Morpho.market(bytes32)` on `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`  
**Arg:** `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836`  
**Block:** **52194988**

Raw return (six `uint128` fields):

| Field | Raw (USDC 6dp) | USD |
|--|--:|--:|
| totalSupplyAssets | `1687800696542806` | $1,687,800,696.542806 |
| totalSupplyShares | `1523204928361816842099` | — |
| totalBorrowAssets | `1519850433803323` | $1,519,850,433.803323 |
| totalBorrowShares | `1354070127798931042102` | — |
| lastUpdate | `1791179323` | — |
| fee | `0` | — |
| **idle (= supply − borrow)** | **`167950262739483`** | **$167,950,262.739483** |

**Verdict:** Idle is **real and present** — about **$167.95M USDC** borrowable liquidity in this market (loan-side cash, not a bag of cbBTC). Prior “$166M / $167.8M” order of magnitude confirmed; this paste pins the raw value at the cited block.

---

## 3) Permission trace — what the vault can and cannot call

**yRSS** `0xF80C0529bD94C773844E459853CD91B9263dD525`

| Check | Live read @ 52194988 |
|--|--|
| Market enabled on yRSS (`config`) | **true** · supply cap **$14,000,000** (`14000000000000`) · capElapsed `0` |
| On supplyQueue | **yes** · index **4** (`supplyQueue(4) == 0x9103…1836`) |
| On withdrawQueue | **yes** · index **1** |
| HOT `isAllocator` | **true** |
| PA `0xA090dD1a701408Df1d4d0B85b716c87565f90467` `isAllocator` | **true** |
| PA flowCaps (yRSS ↔ this market) | maxIn **$2,000,000** · maxOut **$2,000,000** (`2000000000000` / `2000000000000`) |
| PA `admin(yRSS)` | **HOT** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| **yRSS Morpho position** | supplyShares **0** · borrowShares **0** · collateral **0** |
| HOT cbBTC balance | **257** wei — not meaningful borrow collateral |

### Can

- Curator/allocator may **enable / set cap / queue** this market (King = HOT, timelock **0**).
- yRSS may **supply** USDC it holds into this market (subject to cap / PA flowCaps).
- yRSS may **withdraw** only inventory it actually holds as Morpho supply shares here.
- A borrower who posts **real cbBTC** may borrow against the market idle.
- Foreign vaults with PA `maxOut` here may reallocate into King markets (their curator action).

### Cannot

- yRSS **cannot** `withdraw` the **$167.95M idle** — that USDC is other suppliers’ cash. yRSS position is **zero**.
- yRSS **cannot** borrow the idle without posting cbBTC collateral (it holds none).
- Naked “pull idle to HOT” is **not** a vault permission; idle ≠ vault asset.

---

## 4) Governance read (permission root)

| Role | Address | Note |
|--|--|--|
| yRSS owner | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` (**HOT**) | King |
| yRSS curator | **HOT** | King |
| yRSS guardian | `0x0000000000000000000000000000000000000000` | none |
| yRSS timelock | **0** | no delay on curator ops |

**Verdict:** King-controlled vault governance is **proven**. That does **not** equal custody of the $167.95M idle.

---

## 5) Conversion path (physics — not a fire order)

**Physics:** Market idle is **USDC**, loan-side. It is not a bag of cbBTC to swap into USDT/DAI/EURC.

| Step | Mechanism | Seeds |
|--|--|--|
| A | Post **real cbBTC** → `Morpho.borrow` USDC from this idle | HOT USDC / cbBTC |
| B | Foreign vault PA `reallocateTo` into King RSS / yRSS (needs their maxIn) | yRSS / RSS book USDC |
| C | HOT USDC → Spoils / DeepPull Ocean **USDC** leg | Ocean USDC |
| D | USDT · DAI · EURC Ocean legs | **Separate inventory + venues** |

---

## Phase status

| Phase | Status |
|--|--|
| **1 Verification (Proof Set A)** | **PASTED** — this file · full market id · block-numbered idle · permission trace |
| 2 Access / reclaim design | **DENIED** until King accepts + Ocean reconcile |
| 3 Fire | **DENIED** — sealed gates + acceptance |

```
VERIFY_CBBTC_IDLE=1
PROOF_SET_A=1
CHAIN=8453
BLOCK=52194988
MARKET=0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836
IDLE_USDC_RAW=167950262739483
YRSS_POSITION=0
GOVERNANCE=HOT_timelock0
PHASE2=DENIED
```
