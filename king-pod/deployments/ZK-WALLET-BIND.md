# ZK Wallet Bind — Step A LIVE

## Law
Prove **kUSD + RSS@$1 ≥ $700k** from **live hot balances**. Exact sizes private. Poseidon commitment public.

## Circuit
`zk/circuits/wallet_reserves.circom`
- Private: `kusd`, `rss`, `salt`
- Public: `ok`, `commitment=Poseidon(kusd,rss,salt)`, `threshold`, `subject`
- Value: `kusd + floor(rss / 1e12)` (RSS marked $1)

## Prove (pulls chain — refuses free witness)
```bash
cd king-pod/zk
bash scripts/setup-wallet.sh   # once
BASE_RPC=$BASE_RPC bash scripts/prove-wallet.sh
```

## Deploy + submit
```bash
KING_OK=1 FIRE_ZK_WALLET_DEPLOY=1 forge script script/FireZkWalletBindDeploy.s.sol:FireZkWalletBindDeploy --rpc-url $BASE_RPC --broadcast
KING_OK=1 FIRE_ZK_WALLET_PROOF=1 GATE=0x<gate> forge script script/FireZkWalletBindSubmit.s.sol:FireZkWalletBindSubmit --rpc-url $BASE_RPC --broadcast
```

## Live witness (generation)
| Leg | Raw | 6dp value |
|-----|-----|-----------|
| kUSD | 699,994e6 | $699,994 |
| RSS | ~13.03M wei-18 | ~$13,030,000 @ $1 |
| **Total** | | **~$13.73M ≥ $700k** |
