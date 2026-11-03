# ZK Reserves ≥ $700K — LIVE ON BASE

**FIRED. Complete.**

| Contract | Address |
|----------|---------|
| **Groth16Verifier** | `0xCC1223C0fCA9efe6c4ea4b35A8b9F08b3f8aF681` |
| **CrownZkReservesGate** | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| **CrownZkCredit** | `0xeAE626b6e82E51c9805D72B6532A948dcf57D392` |

| Check | State |
|-------|-------|
| Subject | hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| `isProven` | **true** |
| Threshold | **700_000e6** ($700,000) |
| minThreshold | 700_000e6 |
| Credit `maxBorrow` | **0** until USDC is supplied to credit |

### Tx trail
- Deploy: see `broadcast/FireZkDeploy.s.sol/8453/run-latest.json`
- Proof submit: see `broadcast/FireZkSubmitProof.s.sol/8453/run-latest.json`

### Next (capture)
Counterparty / King book: `credit.supply(usdc)` → King `credit.borrow(amt)` (cap 70% of attested = \$490k when book has depth).

Circuit + prove: `zk/scripts/prove.sh` · Counterparty reads `gate.isProven(hot)`.
