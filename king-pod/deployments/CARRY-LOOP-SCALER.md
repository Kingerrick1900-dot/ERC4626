# CarryLoopScaler

Controlled scaler (not recursive leverage).

```bash
ETH_IN=3500000000000000 MAX_LTV_BPS=6000 LOOPS=1 \
  forge script script/CarryLoopScaler.s.sol:CarryLoopScaler --rpc-url $BASE_RPC_URL --broadcast
```

Env knobs: `ETH_IN`, `MAX_LTV_BPS` (cap 7000), `SLIPPAGE_BPS`, `GAS_RESERVE`, `USDC_FLOOR`, `LOOPS` (1–5).

## Live lap (2026-07-18) — LOOP
Funded loop USDC floor → ran scaler once from loop key.

| | |
|--|--|
| swapEth | ~0.00435 ETH |
| cbETH coll | ~0.00383 |
| borrow @60% | ~$4.70 USDC → yRSS |
| left on loop | ~0.0003 ETH gas + ~$1 USDC |

Broadcast: `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL` (`CarryLoopScaler` run-latest on Base).
