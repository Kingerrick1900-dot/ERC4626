# LI.FI free-first — RSS equity migration

**Pattern (King order):** flash is a tool to free collateral, not the extraction.

```text
1 Flash USDC
2 Repay debt                         → creates idle, raises freeable excess
3 Withdraw excess RSS only           → full withdraw reverts under residual debt
4 Supply freed RSS as NEW equity
5 Borrow USDC against new position
6 Repay flash FROM THE BORROW        → residual → Landing
```

**Contract:** `CrownLiFiFreeFirst`  
**Market:** RSS/$1200 `0x41c08085…bf7d88`  
**Fix:** Morpho virtual-share debt math — only **excess** coll is withdrawn.

## Fork results (Base live state)

| Run | Flash | Extra RSS | Landing ask | Landing Δ | Notes |
|--|--|--|--|--|--|
| Migrate only | $700k | 0 | $0 | **$0** | borrow == flash; migration settles |
| Try 700k | $700k | 1M | $700k | **$0.000001** | idle == flash (+1 wei pre-existing) |
| Extra RSS | $5M | 5M | $700k | **$0.000001** | more LTV, same idle cap |

Extra free RSS raises LTV room. It does **not** raise idle. On this matched book, idle created by repay equals the flash, so Landing residual stays **$0**.

## Fire

```bash
cd king-pod
USDC_FLASH=700000000000 LANDING_USDC=0 \
  forge script script/FireLiFiFreeFirst.s.sol:FireLiFiFreeFirst \
  --rpc-url https://mainnet.base.org --broadcast -vvvv
```

Attempt residual (will be $0 while idle==flash):

```bash
USDC_FLASH=700000000000 EXTRA_RSS=1000000000000000000000000 LANDING_USDC=700000000000 \
  forge script script/FireLiFiFreeFirst.s.sol:FireLiFiFreeFirst \
  --rpc-url https://mainnet.base.org --broadcast -vvvv
```
