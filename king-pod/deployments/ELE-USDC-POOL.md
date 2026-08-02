# ELE/USDC UniV3 pool LIVE — no timelock

| Field | Value |
|--|--|
| Pool | [`0x4615a3E473944C12bDF4e1E3d1ea5e5968397410`](https://basescan.org/address/0x4615a3E473944C12bDF4e1E3d1ea5e5968397410) |
| Fee | 0.3% (3000) |
| Price | $1 ELE (sqrtPriceX96 = 2^96 / 10) |
| NPM position | tokenId **5650129** (hot) |
| Seed | **~$59.75 USDC** + **~59.75 ELE** (8dp match) |

## Fire

```bash
KING_GO=1 FIRE_ELE_POOL=1 \
forge script script/FireEleUsdcPool.s.sol:FireEleUsdcPool \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

## Ops note

Pool is thin — sells ELE into it drain USDC seed. Top up USDC/ELE to deepen. Hot kept **$1 USDC** liquid after seed.
