# ZK Reserves ≥ $700K — Circom + Groth16 on Base

**STATUS: BUILT — no broadcast until King FIRE.**

| Step | Action | Tool |
|------|--------|------|
| **1** | Deploy ZK verifier + gate + credit | `FireZkDeploy.s.sol` |
| **2** | Generate proof USDC ≥ $700K | `zk/scripts/prove.sh` (Circom/Groth16) |
| **3** | Submit proof to gate (counterparty-readable) | `FireZkSubmitProof.s.sol` |
| **4** | Borrow against proven reserves | `CrownZkCredit.borrow` |

---

## Circuit

`zk/circuits/reserves.circom` — private `usdcBalance`, public `threshold` + `subject`.  
Proves `usdcBalance ≥ threshold`. Bound to King address.

Threshold default: **700_000e6** ($700,000 USDC raw).

---

## Generate proof

```bash
cd king-pod/zk
USDC_BALANCE=700000000000 THRESHOLD=700000000000 \
  SUBJECT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 \
  bash scripts/prove.sh
# → proofs/proof.json + proofs/proof_solidity.json
```

---

## Deploy on Base (FIRE)

```bash
KING_OK=1 FIRE_ZK_DEPLOY=1 \
  forge script script/FireZkDeploy.s.sol:FireZkDeploy --rpc-url $BASE_RPC --broadcast
```

Logs: `Groth16Verifier` · `CrownZkReservesGate` · `CrownZkCredit`

---

## Submit proof (FIRE)

```bash
cd king-pod/zk && bash scripts/prove.sh   # refresh proof
eval "$(bash scripts/export-proof-env.sh)"
cd ..
KING_OK=1 FIRE_ZK_PROOF=1 GATE=0x<gate> \
  forge script script/FireZkSubmitProof.s.sol:FireZkSubmitProof --rpc-url $BASE_RPC --broadcast
```

Counterparty checks: `gate.isProven(0x6708…)` · `attestations(0x6708…)`

---

## Borrow (step 4)

1. Counterparty / book: `credit.supply(usdcAmt)`  
2. King (after proven): `credit.borrow(amt)` — cap = attested threshold × 70% LLTV  

---

## Note

SNARK proves **knowledge of a balance witness ≥ $700K** bound to subject (not an L1 storage proof).  
For on-chain enforceable USDC, counterparty can also `USDC.balanceOf(subject)` after attestation.

**King FIRE:** `FIRE_ZK_DEPLOY=1` then `FIRE_ZK_PROOF=1`.
