# RFQ — ETH · DAI · USDT · WETH (not USDC dust)

**Kingdom sells RSS. Desk pays real bills money on ETH rails.**

## Prefer — Ethereum mainnet wire (T+0)

Send to Landing EOA **`0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`** on **Ethereum**:

| Asset | Ethereum token | Size |
|-------|----------------|------|
| **ETH** | native | ≥ ~200 ETH (~$500k) or desk quote for $700k |
| **DAI** | `0x6B175474E89094C44Da98b954EedeAC495271d0F` | **500,000–700,000** DAI |
| **USDT** | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | **500,000–700,000** USDT |
| **USDC** | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | **500,000–700,000** USDC |

King releases **RSS on Base** (or agrees ETH-side delivery) on confirmed receipt.

## On-chain Base fill (LIVE)

**CrownMultiStableRail** [`0xbC47996a7B34F049DF4701116BA7936F360a7242`](https://basescan.org/address/0xbC47996a7B34F049DF4701116BA7936F360a7242)  
Stocked **700,000 RSS**.

| Pay | Call |
|-----|------|
| DAI | `fillStable(DAI, amt, amt*1e12, 1)` → Landing Base |
| USDT | `fillStable(USDT, amt, amt*1e12, 1)` → Landing Base |
| WETH | `fillWeth(wethWei, rssOut)` → Landing Base |
| ETH | `fillEth{value}(rssOut)` → Landing Base |
| USDC→ETH | `fillStable(USDC, amt, amt*1e12, 2)` CCTP mint on Ethereum |

Min stable fill **$500k**. Target **$700k**.

## One-liner for desk

> RFQ: **700k RSS** for **700k DAI or USDT** (or ETH/WETH equivalent). Settle **Ethereum** to `0x5Adc…2357` or Base `CrownMultiStableRail`. No AMM. ZK proven. Min $500k.
