# ZK Wallet Bind — Step A LIVE

## Law
Prove **kUSD + RSS@$1 ≥ $700k** from **live hot balances**. Exact sizes private. Poseidon commitment public.

## LIVE Base
| Contract | Address |
|----------|---------|
| Groth16WalletVerifier | `0xbb3C589E7451087290B56578f19bf08C7b1Fc17B` |
| CrownZkWalletGate | `0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579` |
| CrownZkCredit (wired to wallet gate) | `0x3F247ed9A85e0437cC21ddD8c3784eE22E1E7d1A` |
| Proof tx | `0xf2f488b325d309a91fdb802c4541c07d3ab08cbb2b65a17265682711acbf35d3` |
| `isProven(hot)` | **true** |
| threshold | **700000000000** ($700k) |
| commitment | `7327697485179643413195764390621562824984627928541399694080225469553212177479` |

## Circuit
`zk/circuits/wallet_reserves.circom`
- Private: `kusd`, `rss`, `salt`
- Public: `ok`, `commitment=Poseidon(kusd,rss,salt)`, `threshold`, `subject`
- Value: `kusd + floor(rss / 1e12)` (RSS marked $1)

## Prove (pulls chain — refuses free witness)
```bash
cd king-pod/zk
bash scripts/setup-wallet.sh
BASE_RPC=$BASE_RPC bash scripts/prove-wallet.sh
```

## Live witness used
| Leg | 6dp value |
|-----|-----------|
| kUSD | ~$699,994 |
| RSS @$1 | ~$13,030,000 |
| **Total** | **~$13.73M ≥ $700k** |

## Next (B)
Public lender pool on `CrownZkCredit` — systems supply USDC; King draws ≤ 70% of $700k → Landing.
