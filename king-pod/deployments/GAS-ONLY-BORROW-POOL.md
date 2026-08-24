# Gas-only borrowable pool — LIVE

**Mission:** Unmatched USDC on RSS/$1200 King can borrow. Not a $700k ceiling.

## LIVE (Base) — fired

| Piece | Address / value |
|--|--|
| **Pool** | `0xE87e7E4CdB320Ebd761bf7eF8900918D62960bE8` |
| Morpho auth | **true** |
| **gasPark** | **$1,000,000** USDC |
| **yRSS TVL** | **~$1,000,000.39** (was ~$0.37) |
| King yRSS shares | ~4.145e23 |
| Morpho idle | ~$0 (matched — expected after park) |
| Landing USDC | still dust until unmatched idle appears |

Deploy + park txs in `broadcast/FireGasOnlyBorrowPool.s.sol/8453/`.

## Chassis

1. **refreshPack** — $1M flash-bound ticket  
2. **gasPark** — flash → yRSS → borrow vs RSS → repay (**DONE $1M**)  
3. **donateRss** — Lazy Summer NAV  
4. **reallocateIn** — PA pull into RSS/$1200  
5. **poke** — drain all idle → Landing  

## Next

Get **unmatched** USDC on RSS/$1200 (PA / LP answering Peapods), then:

```bash
FIRE=1 POKE=1 POOL=0xE87e7E4CdB320Ebd761bf7eF8900918D62960bE8 \
  forge script script/FireGasOnlyBorrowPool.s.sol --rpc-url https://mainnet.base.org --broadcast --slow
```

Scale park toward yRSS **$14M** cap when ordered.
