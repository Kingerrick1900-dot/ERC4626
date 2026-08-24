# ZK Phase — COMPLETE (Base) · Scroll ops pending key

**Branch:** `cursor/zk-phase-complete-4f7f`  
**Date:** 2026-08-24

---

## Architecture (live)

```
Scroll = settlement (7540/7683 deployed)
Base   = execution (AMO + Morpho) + ZK compliance gates
Flow   = Scroll proves → Base executes (bound + elepan + settlement gates)
```

---

## Base ZK — FIRED ✅

| Gate | Address | Status |
|--|--|--|
| Bound (pack) | `0xab2856626BBd8E6fba9dB93783029eB973E8427F` | `isProven(hot)=true` (7d TTL) |
| Elepan wallet-bind | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` | **proof submitted** `isProven(hot)=true` |
| Settlement (7683) | `0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637` | **proof submitted** `canFill=true` |
| AMO `requireGate` | `0x151C947B813400fE78EE176843F2d666c07422eA` | **true**, `packReady=true` |

### Fire commands (executed)

```bash
# Elepan ZK bind
KING_GO=1 FIRE_ZK_ELEPAN_PROOF=1 GATE=0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30 \
  forge script script/FireZkElepanBindSubmit.s.sol --rpc-url $BASE_RPC_URL --broadcast

# Settlement ZK
KING_GO=1 FIRE_ZK_SETTLEMENT=1 GATE=0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637 \
  forge script script/FireZkSettlementSubmit.s.sol --rpc-url $BASE_RPC_URL --broadcast
```

Proof artifacts: `zk/proofs/elepan_proof_solidity.json`, `zk/proofs/settlement_proof_solidity.json`

---

## Scroll stack — DEPLOYED ✅ · MICRO-FIRE pending

| Layer | Address |
|--|--|
| ERC-7540 vault | `0x846E34c0c83FC3DA7Df953A628CC2FD4E66C434D` |
| ERC-7683 settler | `0x44F92261C9Bf9d6B1798b8756B9135650C615A83` |
| Gold PoR | `0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59` |
| XChain | `0x102c7249fd2C2d8Fe0ec4aea65c4880047E9f8B0` |

### Remaining (needs `SCROLL_PRIVATE_KEY`)

```bash
KING_GO=1 FIRE_MICRO_SCROLL=1 SCROLL_PRIVATE_KEY=… SCROLL_RPC=https://rpc.scroll.io \
  forge script script/FireMicroSeedCapitalize.s.sol \
  --rpc-url $SCROLL_RPC --broadcast --slow
```

Seeds PSM USDC reserve + queues 1 eUSD into 7540 (solver-visible).

---

## Tests

```bash
forge test --match-contract ZkSettlementCompleteTest -vv
forge test --match-contract SovereignAmoLiveForkTest -vv
```

---

## TTL ops

All gates use **7d proof TTL** (settlement: 1d). Re-run before expiry:

- Bound: `FireSovereignActivation` `REFRESH=1`
- Elepan: regenerate proof + `FireZkElepanBindSubmit`
- Settlement: `prove-settlement.sh` + `FireZkSettlementSubmit`

No weak plans.
