# CrownDeedPeel — easy path live

**Deed unmatch → yRSS peel → Landing**

## API

```
board()                         // deed · peelable · idle · debt · util · allowance
peelDust()                      // peel current maxWithdraw (proved path)
unmatch(repayAmt)               // repay-for HOT park debt → util down
unmatchAndPeel(repay, peel)     // one tx: open idle + peel to Landing
pokePeel()                      // robot when idle opens
```

gasPark / borrow = revert.

## Fire

```bash
# Deploy + approve + peel dust
KING_GO=1 forge script script/FireDeedPeel.s.sol:FireDeedPeel \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# When HOT holds USDC wedge (found/engineered):
KING_GO=1 UNMATCH_PEEL=1 PEEL_DUST=0 \
  forge script script/FireDeedPeel.s.sol:FireDeedPeel \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Physics

Park ~100% util → peelable ≈ idle dust.  
`unmatch` repays HOT borrow → idle opens → same proved `yrss.withdraw` peels the deed.
