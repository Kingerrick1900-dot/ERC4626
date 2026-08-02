# Full-Stack Protocol Automation — LIVE

**Branch:** `cursor/fullstack-protocol-stack-efa1`  
**Doctrine:** code-first Base ↔ Scroll balance sheet. No keeper scripts. No relationship dependencies.

```
1 ERC-7540 QUEUE ──► 2 ERC-7683 INTENTS ──► 3 Chainlink PoR
                                              │
4 Uniswap v4 Hook (Base)          5 CCIP/LZ Settlement (Base↔Scroll)
```

---

## Live addresses

### Scroll (534352)

| Layer | Contract | Address |
|--|--|--|
| **1. ERC-7540** | `CrownElepanAsyncVault` | [`0x846E34c0c83FC3DA7Df953A628CC2FD4E66C434D`](https://scrollscan.com/address/0x846E34c0c83FC3DA7Df953A628CC2FD4E66C434D) |
| **2. ERC-7683** | `CrownPsmIntentSettlement` | [`0x44F92261C9Bf9d6B1798b8756B9135650C615A83`](https://scrollscan.com/address/0x44F92261C9Bf9d6B1798b8756B9135650C615A83) |
| **3. PoR** | `CrownGoldCdpPoRFeed` | [`0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59`](https://scrollscan.com/address/0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59) |
| **5. XChain** | `CrownCrossChainSettlement` | [`0x102c7249fd2C2d8Fe0ec4aea65c4880047E9f8B0`](https://scrollscan.com/address/0x102c7249fd2C2d8Fe0ec4aea65c4880047E9f8B0) |

Wrapped PSM (unchanged): `0x064489A287448674AA1dC6fb740d2F518CBA75dA` (Gold Parity / Elepan PSM)

### Base (8453)

| Layer | Contract | Address |
|--|--|--|
| **3. PoR** | `CrownEle77PoRFeed` | [`0x3640f1CC913B772EA4D9BDF96a67196590058379`](https://basescan.org/address/0x3640f1CC913B772EA4D9BDF96a67196590058379) |
| **4. v4 Hook** | `CrownEusdV4Hook` | [`0xD439DC646C807BFa704EE726fD9fCcfFde6605a7`](https://basescan.org/address/0xD439DC646C807BFa704EE726fD9fCcfFde6605a7) |
| **5. XChain** | `CrownCrossChainSettlement` | [`0xbedA9C5da5582B6FD293a9a77b754FA2CB0B8982`](https://basescan.org/address/0xbedA9C5da5582B6FD293a9a77b754FA2CB0B8982) |

Peers wired: Scroll xchain ↔ Base xchain (`setPeer` txs `0x730002dd…` / `0xe00d8bd8…`).

---

## Layer specs (shipped)

### 1 — ERC-7540 Async Queue
- `requestRedeem` locks Scroll eUSD; no instant PSM call
- `fulfillRedeem` / `fulfillRedeemBatch` → `PSM.redeemUsdc`
- `claimRedeem` releases USDC
- Eliminates request/execution races via batched fulfillment

### 2 — ERC-7683 Intents
- `ISettlementContract` on `CrownPsmIntentSettlement`
- `open` → queues into ERC-7540 vault
- `fill` → solver fronts USDC to user (Base recipient)
- `settle` → reclaim PSM USDC via vault fulfill+claim
- Public solver fill enabled by default

### 3 — Chainlink PoR
- **ELE77:** AggregatorV3 `latestRoundData` → Morpho `totalSupplyAssets` (live **~$16.52M**)
- **Gold CDP:** AggregatorV3 → `coll * oracle / 1e36` (live **$1,000,010**)
- Solvers / institutions read on-chain backing without trust assumptions

### 4 — Uniswap v4 Hook
- Hook permissions: `afterInitialize` + `afterSwap`
- TWAP-window reference price for eUSD/USDC (`getReferencePrice`)
- PoolManager: `0x498581fF718922c3f8e6A244956aF099B2652b2b`
- Hook address must be CREATE2-mined with flag bits when attaching to a v4 pool

### 5 — CCIP / LayerZero Settlement
- Dual-rail: existing Base/Scroll eUSD **Link** path + CCIP/LZ endpoints
- `settleToScroll` / `settleToBase` + `ccipReceive` / `lzReceive`
- Links wired: Base `0x860E…` · Scroll `0xb7b1…`
- LZ Endpoint V2 both chains: `0x1a44076050125825900e736c501f859c50fE728c`

---

## Fire commands

```bash
# Scroll layers 1+2+3(gold)+5
KING_GO=1 FIRE_STACK_SCROLL=1 forge script script/FireProtocolStack.s.sol:FireProtocolStack \
  --rpc-url $SCROLL_RPC --broadcast --slow

# Base layers 3(ELE77)+4+5
KING_GO=1 FIRE_STACK_BASE=1 forge script script/FireProtocolStack.s.sol:FireProtocolStack \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Tests

```bash
forge test --match-contract ProtocolStackTest -vv
# 5/5 passing: 7540, 7683, PoR, v4 hook, xchain wire
```

## Status

| Gate | Result |
|--|--|
| Compile | ✅ |
| Unit tests | ✅ 5/5 |
| Scroll deploy | ✅ `STACK_SCROLL_OK` |
| Base deploy | ✅ `STACK_BASE_OK` |
| Peer wire | ✅ |
| Live PoR read | ✅ ELE77 + Gold |
