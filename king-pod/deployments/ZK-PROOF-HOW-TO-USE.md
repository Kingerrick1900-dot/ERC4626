# ZK Reserves — How King Uses the Proof (Proper)

**The proof is the loan ticket.** It is already on Base. Stop treating it like an empty vault.

---

## What is LIVE

| Item | Value |
|------|--------|
| Gate | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| Subject (King hot) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Claim proven | **USDC reserves ≥ \$700,000** |
| `isProven(hot)` | **true** |
| Proof tx | `0x356017a9f494cf0e5a1b83671e72c24b8b818d7c95bdea37248c53f3128b9e11` |
| Verifier | `0xCC1223C0fCA9efe6c4ea4b35A8b9F08b3f8aF681` |
| Credit rail (optional settle) | `0xeAE626b6e82E51c9805D72B6532A948dcf57D392` |

Counterparty does **not** need King’s private balance. They verify the gate.

---

## Proper use (industry pattern)

Same pattern as zkLoans / ZK credit underwriting:

1. **King proves** threshold (done — Groth16 on Base)  
2. **Lender verifies** on-chain boolean — not bank statements  
3. **Lender advances USDC** against that attestation  
4. **Settle** via wire to Landing, or `CrownZkCredit.supply` → King `borrow`

The SNARK is the underwrite. Cash comes from the **counterparty who accepts the proof**.

---

## Counterparty verify (one screen)

```bash
# Base
cast call 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205 \
  "isProven(address)(bool)" \
  0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url $BASE_RPC
# → true

cast call 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205 \
  "attestations(address)(uint256,uint256,bool)" \
  0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url $BASE_RPC
# → threshold 700000000000 · provenAt · valid true
```

Basescan: gate · proof tx above.

---

## How King secures the loan with it

| Path | What counterparty does | King gets |
|------|------------------------|-----------|
| **A — OTC wire** | Verify `isProven` → wire USDC to Landing `0x5Adcea53…2357` | Spendable USDC |
| **B — Credit contract** | `supply(USDC)` on `0xeAE626…D392` → King `borrow` (70% of \$700k = \$490k cap) | On-chain draw |
| **C — Desk/bond fill** | Accept proof as solvency → buy RSS on desk/bond → USDC to Landing | Raise + inventory clear |

**King’s move:** send this packet. Proof is the ask. Lender funds against it.

---

## One-liner for the desk

> Kingdom hot `0x6708…a7d1` has an on-chain Groth16 attestation that reserves ≥ \$700,000 USDC. Verify `CrownZkReservesGate.isProven` on Base. Advance credit against that attestation; settle to Landing or `CrownZkCredit`.
