# Elepan ZK — COMPLETE

**Branch:** `cursor/zk-elepan-complete-efa1`  
**Status:** Wallet-bind + reserves + credit + settlement proofs **shipped**. ERC-7540 / ERC-7683 **unchanged**.

---

## Stack

| Layer | Circuit / Contract | Role |
|--|--|--|
| 1 Reserves | `reserves.circom` → `CrownZkReservesGate` | USDC ≥ threshold |
| 2 Wallet / Elepan bind | `wallet_reserves.circom` → `CrownZkWalletGate` | kUSD+RSS / Elepan Poseidon commitment |
| 3 Credit | `CrownZkCredit` + AutoDraw / LoanComplete / YieldLadder | Proven draws → Landing |
| 4 Settlement | `settlement.circom` → `CrownZkSettlementGate` | Solver liquidity ≥ minUsdc bound to 7683 orderId |
| 5 Hardening | `ProofVecGuard` + Certora specs + CDP `zkFallback` | Under-constraint / silent-fail class |

## Live (existing Base)

| Piece | Address |
|--|--|
| Wallet verifier | `0xbb3C589E7451087290B56578f19bf08C7b1Fc17B` |
| Wallet / Elepan gate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| Credit rail | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| AutoDraw | `0xE7e7008D71387a79Bf57F1E5Ab75534d4b3DA34A` |
| LoanComplete | `0x12514e1f999131eA78D402a7258b67A65F9342Ff` |
| Reserves verifier / gate | `0xCC12…F681` / `0xAf95…7205` |

**Ops note:** Elepan wallet gate `isProven(hot)` may read `false` after 7-day TTL — re-run `prove-elepan.sh` + `FireZkElepanBindSubmit` against the **live VK** (not a new hardened VK until cutover).

## Settlement (this PR — LIVE Base)

| Piece | Address |
|--|--|
| `Groth16SettlementVerifier` | [`0xdb62d9564231b7d69E95f3e8C622458EFBa099d4`](https://basescan.org/address/0xdb62d9564231b7d69E95f3e8C622458EFBa099d4) |
| `CrownZkSettlementGate` | [`0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637`](https://basescan.org/address/0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637) |

Solver flow (7540/7683 untouched):

1. Prove `liquidity ≥ minUsdc` for field-reduced `orderId` + filler  
2. `settlementGate.submitProof(...)`  
3. Call live `CrownPsmIntentSettlement.fill` / vault `fulfillRedeem`  

## Fixes in this PR

- `ZkKingGate` / `CrownZkLoanComplete` attestation ABI aligned to `(threshold, provenAt, bool)`
- Settlement circuit + Groth16 VK + gate + prove/setup scripts
- `CONSTRAINT-AUDIT.md` restored
- a16z memo: ZK marked **shipped**, not later

## Fire

```bash
# Settlement verifier + gate (Base)
KING_GO=1 forge script script/FireZkSettlement.s.sol:FireZkSettlement \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# Prove settlement (local)
cd king-pod/zk && bash scripts/prove-settlement.sh <liq6> <orderId> <min6> <filler>
```

## Tests

```bash
forge test --match-contract ZkSettlementCompleteTest
forge test --match-contract CrownZkHardeningTest
forge test --match-contract MultiAssetPsmTest
```
