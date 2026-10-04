# a16z Handoff Index — Kingdom AMO Package

## Package contents

| Doc | Path |
|--|--|
| Ocean external-leg law | `deployments/SEALED-OCEAN-EXTERNAL-LEGS.md` |
| $3M A+B sealed params | `deployments/SEALED-3M-AB.md` |
| $3M A+B fire record | `deployments/FIRE-3M-AB.md` |
| AMO 6 armor audit | `deployments/AMO6-ARMOR-AUDIT.md` |
| Execution order | `deployments/AMO6-EXECUTION-ORDER.md` |
| Flash policy | `deployments/FLASH-POLICY.md` |
| King-side USDC lock | `deployments/KING-SIDE-USDC-LOCK.md` |

## Armor source

| Contract | Path |
|--|--|
| Circuit breaker | `src/CrownCircuitBreaker.sol` |
| ColdBuffer law | `src/ColdBufferLaw.sol` |
| Mint gate | `src/MintGate.sol` |
| ColdBuffer | `src/CrownColdBuffer.sol` |
| Revenue sweep (A) | `src/CrownRevenueSweep.sol` |
| Gold convert (B) | `src/CrownGoldConvert.sol` |

## Tests

```bash
forge test --match-contract Amo6ArmorTest -vv
forge test --match-contract RouteABTest -vv
```

## Scoreboard oracles (numbers only)

- `yRSS.totalAssets()`  
- `USDC.balanceOf(HOT)`  
- `MintGate.canMint()` / `unlocked`  
- `CrownCircuitBreaker.armed` / `tripped`  
- `ColdBuffer.minBufferBps()`  

## Explicit non-goals

- No OTC / Circle beg  
- No AMO on self-paired Ocean alone  
- No FlashBleed wiring  
- No tranche unlock without King  
- No AxCNH without King signature  
