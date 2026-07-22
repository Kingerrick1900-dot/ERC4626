# RSS / WETH · RSS / cbBTC - fat Morpho lane

**Doctrine shift:** Stop chasing Aero RSS/USDC dust. Point at Morpho’s fat inventory.

| Asset in Morpho (Base) | Approx inventory |
|------------------------|------------------|
| WETH | **~75,000** |
| cbBTC | **~36,000** |
| USDC | **~$178M** |

## Fire next

```bash
KING_OK=1 FIRE_RSS_WETH_CBBTC=1 forge script script/FireRssWethCbbtcMarkets.s.sol:FireRssWethCbbtcMarkets \
  --rpc-url $BASE_RPC --broadcast
```

Opens two Morpho Blue markets (LLTV **77%**, AdaptiveCurve IRM):

| Market | Collateral | Loan | Oracle |
|--------|------------|------|--------|
| RSS/WETH | RSS | WETH | Fixed \$1 RSS x UniV3 WETH/USDC TWAP |
| RSS/cbBTC | RSS | cbBTC | Fixed \$1 RSS x UniV3 cbBTC/USDC TWAP |

TWAP pools (fat, not RSS dust):

- WETH/USDC 0.05% `0xd0b53D9277642d899DF5C87A3966A349A798F224`
- cbBTC/USDC 0.05% `0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef`

## What this does / does not

- **Does:** Create borrowable RSS->WETH and RSS->cbBTC books on Morpho. Flash source for later machines = Morpho WETH/cbBTC balances (fat).
- **Does not:** Instantly print WETH/cbBTC - loan side still needs suppliers (or a flash+repay path). Hot has **0** WETH / **0** cbBTC to self-seed.

## After create

1. Post RSS collateral on the new markets.
2. Borrow when WETH/cbBTC liquidity is supplied (external lenders or kingdom seed).
3. Route loan assets -> Landing (cold-or-revert).
4. MultiStableRail already accepts WETH desk fills for RSS.

## Gas

Hot ETH is thin - top up before broadcast if deploy reverts.
