# ZK Elepan Wallet Bind — LIVE

## Law
Prove **Elepan@$1 ≥ $700k** from **live hot Elepan balance**. Exact size private. Poseidon commitment public.
Reuses RSS `wallet_reserves` circuit + live `Groth16WalletVerifier` (no new trusted setup).

## Mapping
Elepan is **8dp**. Circuit marks RSS as $1 via `floor(rss / 1e12)` (18dp → 6dp).
Prove script sets `kusd=0`, `rss = elepan * 1e10` so `floor(rss/1e12) = floor(elepan/100)` = USD 6dp.

## LIVE Base
| Contract | Address |
|----------|---------|
| Groth16WalletVerifier (shared) | `0xbb3C589E7451087290B56578f19bf08C7b1Fc17B` |
| CrownZkElepanGate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| CrownZkElepanCredit (institutional USDC rail) | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| Proof tx | `0xe5630deb4889ad574c64feeb9ac884dad2857125894ecfc3f956515d11771d88` |
| `isProven(hot)` | **true** |
| threshold | **700000000000** ($700k) |
| commitment | `9988976819989251114383495759007802807695296219280798532360944962322712008114` |

## Prove (pulls chain — refuses free witness)
```bash
cd king-pod/zk
BASE_RPC=$RPC bash scripts/prove-elepan.sh
# then submitProof to GATE (cast or FireZkElepanBindSubmit)
```

## Live witness used
| Leg | 6dp value |
|-----|-----------|
| Elepan @$1 | ~$99.92M |
| **Total** | **≫ $700k** |

## Private vault rail
`CrownZkElepanCredit` — same pattern as RSS ZK credit pool B: external USDC lenders supply; proven subject draws ≤ 70% of attested threshold to Landing.
**Zama FHE** encrypted balances = deferred (Morpho confidentiality / FHE next phase).
