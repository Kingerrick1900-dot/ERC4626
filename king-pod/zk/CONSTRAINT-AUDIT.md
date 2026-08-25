# Constraint Audit — Elepan ZK Circuits

## Circuits

| Circuit | Public inputs | Private | Purpose |
|--|--|--|--|
| `reserves.circom` | ok path: threshold, subject | usdc | v1 USDC ≥ threshold |
| `wallet_reserves.circom` | threshold, subject | kusd, rss, salt | Wallet-bind / Elepan-bind |
| `settlement.circom` | orderId, minUsdc, subject | liquidity, salt | ERC-7683 fill attestation |

## Hardening rules (all circuits)

1. Every private limb that enters a comparison is `Num2Bits`-ranged.
2. Public `subject` is bound to 160 bits (EVM address).
3. `ok` is forced boolean: `ok * (ok - 1) === 0`.
4. Commitments bind privates via Poseidon so public outputs cannot be forged without witnesses.
5. Multi-tx circuits MUST bind `numTxs` to the full proven set (N/A for single-shot circuits here).

## Settlement vs 7540/7683

Settlement proofs attest solver inventory off the critical path. Live `CrownElepanAsyncVault` and `CrownPsmIntentSettlement` are **not modified**. Solver flow: `submitSettlementProof` → `fill` / `fulfillRedeem` on existing contracts.

## Silent-failure class

On-chain gates emit `SilentFailureFlag` and expose `checkSilentFailure` — ZK bugs often succeed as txs.
