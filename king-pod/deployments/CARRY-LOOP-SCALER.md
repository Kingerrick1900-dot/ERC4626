# CarryLoopScaler — HALTED

**Status: STOPPED (2026-07-18).** King killed the carry. Morpho position under loop is **flat**.

Script refuses to broadcast unless `CARRY_ARMED=1`.

## Closed position
| | |
|--|--|
| Morpho cbETH/USDC | **0 / 0** |
| Loop ETH | ~0.00461 |
| Loop USDC | ~$1.00 floor |
| Loop yRSS | dust shares only (~0 assets) |

Unwind txs: repay `0x6bf9b9c2…` → withdrawCollateral `0x96c7e568…` → Aero `0xd25eb8e8…`.

## Do not run
```bash
# blocked unless armed
forge script script/CarryLoopScaler.s.sol:CarryLoopScaler --rpc-url $BASE_RPC_URL --broadcast
# only if King re-arms:
# CARRY_ARMED=1 LOOP_PRIVATE_KEY=… forge script …
```
