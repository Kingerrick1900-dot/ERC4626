# CrownCbbtcIdlePuller — idle from dust → millions

**Doctrine:** Code obeys the king. Pull millions at will when cbBTC is funded.

## Live

| Contract | Address |
|--|--|
| **CrownCbbtcIdlePuller** | `0xE55f6Ac1a5Fb7337AD82886E82c549A00F0B6F3B` |
| Status | **ARMED** · await cbBTC fund |
| Ask | **$1.5M** lasting park USDC idle |
| Coll need | **2,320,034,157** wei ≈ **23.20 BTC** |
| HOT cbBTC now | **1028** wei dust · max pull now ≈ **$0.66** |
| cbBTC book idle | ~**$195.1M** |

## Dust ladder (already live)

| Step | Contract | Result |
|--|--|--|
| Dust peel | CrownVaultSolver | $1 willFromZero |
| Unlatch | `0xEC8474…FFC4` | **+$1.51** park USDC idle |
| Fake idle | `0xFCD6BB…596E` | Morpho-visible **eUSD** idle |
| Ocean | `0x5AE228…c099` | Aero eUSD/gUSD **~5B/5B** |
| King rail | `0xaE87f8…14c8` | P2 **$2M eUSD→Landing** · P3/P4 armed |
| **cbBTC puller** | `0xE55f6A…6F3B` | Lasting park USDC idle via cbBTC L2 |

## Physics

```
flash USDC (Morpho)
→ supply PARK (USDC/RSS)     ← unmatched idle STAYS
→ supplyCollateral cbBTC
→ borrow USDC on cbBTC/USDC  ← repay flash from ~$195M book
→ park idle = equity@haircut LLTV
```

gasPark / same-book borrow = revert.

## Sizing (live oracle · LLTV 86% · haircut 95%)

| Idle ask | cbBTC needed (approx) |
|--|--|
| $1.5M | ~**23.2 BTC** |
| $2.0M | ~**30.9 BTC** |
| $5.0M | ~**77.3 BTC** |
| $10M | ~**154.6 BTC** |

Book headroom: cbBTC/USDC Morpho idle ~**$195M** — millions are liquid when coll posts.

## API

```
quoteMaxIdle(cbbtc)           // USDC idle capacity
quoteCollForIdle(usdc)        // cbBTC wei for ask
wealthBoard()                 // park idle · book idle · ask · coll · maxPullNow
pullIdle(usdc, cbbtc)         // engineer lasting idle (0/0 = max from king bal)
pullMillions()                // DEFAULT_ASK $1.5M
buyCbbtcAndPull(usdc,min,idle)// Uni buy then L2 (USDC path)
```

## Fire

```bash
# Armed deploy (done):
KING_GO=1 forge script script/FireCbbtcIdle.s.sol:FireCbbtcIdle \
  --rpc-url $BASE_RPC_URL --broadcast --slow
# When HOT cbBTC ≥ quote:
KING_GO=1 FIRE_CBBTC_IDLE=1 IDLE_ASK=1500000000000 \
  forge script script/FireCbbtcIdle.s.sol:FireCbbtcIdle \
  --rpc-url $BASE_RPC_URL --broadcast --slow
# Or king-direct:
# cbbtc.approve(0xE55f…6F3B, max); puller.pullMillions();
```

## Still needs King

1. **Fund HOT with cbBTC** (~23.2 BTC for $1.5M lasting park idle) — OTC / treasury / post-payroll  
2. Or fund USDC and `buyCbbtcAndPull` (direct park supply is more efficient for pure USDC)  
3. Rail P3 still wants `yrss.approve(rail)` + cbBTC for payroll liberate  

Kingdom eUSD/gUSD wealth = magnet/optics — not Circle USDC. This puller turns **real cbBTC** into **real lasting Morpho USDC idle**.
