# KING RAIL — engineered · LIVE

**Doctrine:** Code obeys the king.

## Live

| Contract | Address |
|--|--|
| **CrownKingRail** | `0xaE87f8124999b20F870Ef92491133b897e1b14c8` |
| CrownOceanSeeder | `0x5AE22813c4560fA28a3C2e4c7e918Da42904c099` |
| CrownFakeIdleEusd | `0xFCD6BB3284b8560c0ec733c2E3c6E9848100596E` |
| CrownUnlatchIdle | `0xEC847430Ac0667B75A0a0647a269ee286587FFC4` |

## Fired this lift

| Step | Result |
|--|--|
| **P2** | ~**$2M eUSD** piped HOT → Landing via Morpho (withdraw-by-shares) |
| **P5 ocean** | +**3.979B/side** → Aero pool target **~5B / ~5B** |
| **P4 coll** | **cbBTC** named · rail armed `minIdleBuffer=$1.5M` |
| **P3/P4** | Engineered on rail — fire when cbBTC on HOT + `yrss.approve(rail)` |

## Rail API (king)

```
p1LandingWithdrawEusd(amt)     // Landing key — L0 idle pull
p2PipeEusdToLanding(amt)       // HOT eUSD → Landing
p3PayrollWithCbbtc(usdc, cbbtc)// Flash payroll → Landing (cbBTC repay book)
p4AsymIdle(usdcIdle, cbbtc)    // Lasting park USDC idle
```

gasPark / same-book borrow = revert.

## Still needs King

1. **Landing key** → `p1LandingWithdrawEusd(2e18*1e18)` for full $4M liquid stack  
2. **cbBTC source** → fund HOT → `p3` payroll and/or `p4` lasting $1.5M USDC idle  
3. `yrss.approve(0xaE87…14c8, max)` before P3  
