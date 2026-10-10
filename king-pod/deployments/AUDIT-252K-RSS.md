# AUDIT — 252,000 RSS Morpho position (Step 1)

**Mode:** AUDIT · live Base reads · **no fire · no re-param**  
**Chain:** Base · **chainId `8453`**  
**Read block:** **52195008** · timestamp **1791179363** · block hash `0x2ac111313810e7ca691b89214f2a9400e8b97ed5d6bdfd94b34259c91edb8a27`  
**Caller:** public `cast call` (read-only) against Morpho Blue singleton  
**Law:** Step 1 authorized by audit. Engineering remains gated behind Proof Sets A + B.

---

## 1) Market identity (full, not truncated)

This is a **Morpho Blue market id** (bytes32) on the Morpho singleton — not a standalone ERC4626 vault.

| Field | Full value |
|--|--|
| **Market id** | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| **Morpho Blue** | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| **Loan token (USDC)** | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| **Collateral (RSS)** | `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| **Oracle** | `0xB5840644142B341a6145335e2ebc82EEBC7aE1B9` |
| **IRM** | `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| **LLTV (liquidation threshold)** | `770000000000000000` = **77%** |

`cast call Morpho.idToMarketParams(0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88)` @ block **52195008** returned the five-tuple above (loan, collateral, oracle, irm, lltv).

Morpho app: https://app.morpho.org/base/market/0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88

---

## 2) Posted amount — 252,000 RSS verified on-chain

`Morpho.position(marketId, HOT)` @ block **52195008**:

| Field | Raw return | Human |
|--|--:|--:|
| supplyShares | `293029848116195` | ~$1,171.21 USDC supply (derived) |
| borrowShares | `193121172299006654781` | sole-borrower book (see below) |
| **collateral** | **`252000000000000000000000`** | **exactly 252,000 RSS (18dp)** |

**Verdict:** The **252,000** figure is **proven**. Raw collateral = `252000 * 10^18`. No truncation, no assertion.

Position holder (**HOT / King**): `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`

yRSS `0xF80C0529bD94C773844E459853CD91B9263dD525` on this market: collateral **0**, borrowShares **0**, supplyShares `64373430597812219536` (vault is the supply side).

---

## 3) Market book + utilization (same block)

`Morpho.market(0x41c0…7d88)` @ block **52195008**:

| Field | Raw | Human |
|--|--:|--:|
| totalSupplyAssets | `257294976498833` | $257,294,976.498833 USDC |
| totalSupplyShares | `64373724126544706622` | — |
| totalBorrowAssets | `257294976498833` | $257,294,976.498833 USDC |
| totalBorrowShares | `193121172299006654781` | — |
| lastUpdate | `1791099307` | stored; view not force-accrued |
| fee | `0` | — |
| **idle (supply − borrow)** | **`0`** | **100% utilization** |

HOT `borrowShares` **equals** `totalBorrowShares` → HOT is the **sole borrower** of this book.  
Derived HOT borrow assets = `totalBorrowAssets` = **`257294976498833`** (USDC 6dp).

---

## 4) Oracle · collateral value · current LTV

`oracle.price()` @ `0xB5840644142B341a6145335e2ebc82EEBC7aE1B9` · block **52195008**:

| Field | Raw | Meaning |
|--|--:|--|
| price | `1200000000000000000000000000` (`1.2e27`) | Morpho scale → **$1,200 / RSS** |

Morpho collateral value (loan units) = `collateral * price / 1e36`:

| Meter | Value |
|--|--:|
| Collateral value | `302400000000000` USDC 6dp = **$302,400,000.00** |
| Borrow assets | `257294976498833` USDC 6dp = **$257,294,976.498833** |
| **Current LTV** | **85.084318%** (`850843176252754629` wad) |
| **LLTV** | **77%** |
| Max borrow @ LLTV | `232848000000000` ($232,848,000) |
| Health factor (coll·LLTV / borrow) | **0.904985** |

**Audit finding (not softened):** At this block, **LTV 85.08% > LLTV 77%**. The stored Morpho view marks this position **over the liquidation threshold**. Interest may push further on next accrue. This is a fact of the read, not a recommendation.

**Oracle $50k command:** Paper LTV at $50,000 would be ~2.04%. Live oracle is still **$1,200** — immutable bytecode, no `setPrice`. See `ORACLE-50K-COMMAND-RECORD.md`. Commanded ≠ executed.

---

## 5) Key holder — address + controller

| Role | Address | Type |
|--|--|--|
| **Position owner (borrower / collat poster)** | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | **EOA + EIP-7702 delegation** (not multisig, not timelock) |
| Delegation target (code @ HOT) | `0x63c0c19a282a1b52b07dd5a65b58948a07dae32b` | bytecode `0xef0100` + 20-byte impl (codesize **23**) |
| Controller | King key for HOT — signs as `0x6708…a7d1` | sole Morpho authorization for self: `isAuthorized(HOT,HOT)=true` |
| yRSS owner | **HOT** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | — |
| yRSS curator | **HOT** | — |
| yRSS guardian | `0x0000000000000000000000000000000000000000` | none |
| yRSS timelock | **`0`** | no delay |
| Public Allocator | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` | `isAllocator=true`; PA `admin(yRSS)=HOT` |
| PA flowCaps (yRSS ↔ this market) | maxIn **$5,000,000** · maxOut **$5,000,000** (`5000000000000` / `5000000000000`) | live @ same chain |

**Verdict:** Keyholder is **HOT EOA (King)**, EIP-7702-delegated, **not** a Safe/multisig and **not** behind a timelock. yRSS governance is the same HOT with `timelock=0`.

---

## 6) Related live context (same session)

| Check | Result @ 52195008 |
|--|--|
| HOT wallet RSS balance | `0` (all 252k is Morpho collateral) |
| yRSS `maxWithdraw(HOT)` | `0` (market 100% util — exit blocked) |
| yRSS `totalAssets()` | `262572466048669` (~$262.57M) |
| yRSS config(this market) | enabled **true** · supply cap **$500,000,000** (`500000000000000`) |
| On yRSS supplyQueue | **yes** · index **0** |

---

## Cast recipe (reproducible)

```bash
BASE_RPC_URL=${BASE_RPC_URL:-https://mainnet.base.org}
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
M=0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
ORACLE=0xB5840644142B341a6145335e2ebc82EEBC7aE1B9
BN=$(cast block-number --rpc-url $BASE_RPC_URL)

cast call $MORPHO "idToMarketParams(bytes32)(address,address,address,address,uint256)" $M --rpc-url $BASE_RPC_URL --block $BN
cast call $MORPHO "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" $M --rpc-url $BASE_RPC_URL --block $BN
cast call $MORPHO "position(bytes32,address)(uint256,uint128,uint128)" $M $HOT --rpc-url $BASE_RPC_URL --block $BN
cast call $ORACLE "price()(uint256)" --rpc-url $BASE_RPC_URL --block $BN
```

---

```
AUDIT_252K_RSS=1
CHAIN=8453
BLOCK=52195008
MARKET=0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
COLLATERAL_RAW=252000000000000000000000
COLLATERAL_RSS=252000
BORROW_USDC6=257294976498833
ORACLE_PRICE=1200000000000000000000000000
LTV_PCT=85.084318
LLTV_PCT=77
KEYHOLDER=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
KEY_TYPE=EOA_EIP7702
TIMELOCK=0
ENGINEERING=GATED_UNTIL_PROOF_A_AND_B
```
