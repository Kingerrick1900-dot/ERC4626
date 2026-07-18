# CarryLoopScaler

Controlled scaler (not recursive leverage).

```bash
ETH_IN=3500000000000000 MAX_LTV_BPS=6000 LOOPS=1 \
  forge script script/CarryLoopScaler.s.sol:CarryLoopScaler --rpc-url $BASE_RPC_URL --broadcast
```

Env knobs: `ETH_IN`, `MAX_LTV_BPS` (cap 7000), `SLIPPAGE_BPS`, `GAS_RESERVE`, `USDC_FLOOR`, `LOOPS` (1–5).

Path: ETH → Aerodrome cbETH → Morpho `0x1c21c59df9…` supplyCollateral → borrow ≤60% LTV → yRSS → BRETT.
