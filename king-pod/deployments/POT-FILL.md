# Pot fill — Keyrock pattern (kingdom-owned)

Foreign PA `reallocateTo` cannot fill an **empty** vault. Gauntlet `maxIn=0`.  
**Means:** Morpho flash (system USDC float ~$178M) → deposit `yELE-K` → realloc ELE Blue → borrow repay flash.

| Result | |
|--|--|
| Vault TVL | = `ASK_USDC` (working pot) |
| King debt | += ask (finances the pot — Keyrock dual book) |
| Landing | dust skim only if idle remains |

```bash
KING_GO=1 FIRE_POT=1 ASK_USDC=700000000000 \
forge script script/FirePotFill.s.sol:FirePotFill \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Vault: `0x0D96ba80502Eb8A08A6d3bd4680134b20C229532`
