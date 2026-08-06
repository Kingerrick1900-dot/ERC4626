# RSS/USDC leverage loop — no ETH

**Equity:** free RSS (Kingdom inventory)  
**Working capital:** Morpho USDC flash  
**Not fired live** — Landing residual ~$0 while idle == flash (same matched-book wall).

## Loop legs
1. Pull free RSS → `supplyCollateral` (LTV room)
2. Flash USDC → `supply` (creates idle)
3. Borrow vs RSS → repay flash; residual → Landing

## Fork
| Ask | Landing Δ |
|--|--|
| $700k | **$0.000001** |
| migrate only | **$0** |

RSS loop replaces WETH/ETH Venus equity. Does not mint Circle USDC from a 100% util self-book.
