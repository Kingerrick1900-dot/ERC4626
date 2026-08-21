# Gas-only borrowable pool — plan of action (LIVE pipe)

**Mission:** Engineer unmatched USDC on RSS/$1200 King can borrow. Not a $700k scoreboard.

## Already true on Base

| Piece | State |
|--|--|
| Peapods scream | **LIVE** — fUSDC 100% util (demand beacon) |
| Morpho $200M signal | Intact — 250k RSS coll, ~$31M room, **idle ≈ $0** |
| yRSS | Cap **$14M** on RSS/$1200 · queue armed · curator/PA admin = hot |
| Pack gate/flash | LIVE — TTL refresh via `refreshPack` |
| Free RSS | ~9.6M on hot |

## Chassis: `CrownGasOnlyBorrowPool`

Survivor stack in one contract:

1. **refreshPack** — flash-bound $1M ticket (gas only)  
2. **gasPark** — Kamino/SelfSeed: Morpho flash → yRSS → borrow vs RSS → repay (war chest, no pocket USDC)  
3. **donateRss** — Lazy Summer NAV (oracle-priced RSS)  
4. **reallocateIn** — Morpho PA pull WETH/cbBTC vault depth → RSS/$1200  
5. **poke / borrowToLanding** — drain **all** idle to Landing (no ceiling)

## Fire (hot key)

```bash
FIRE=1 PARK=1 USDC_AMT=1000000000000 RSS_COLL=0 \
  forge script script/FireGasOnlyBorrowPool.s.sol:FireGasOnlyBorrowPool \
  --rpc-url https://mainnet.base.org --broadcast --slow
```

Optional: `REFRESH=1` · `POKE=1` when idle > 0.

## Physics

- `gasPark` = matched Morpho (yRSS supply + king debt). Builds vault TVL.  
- **Borrowable idle** = unmatched USDC (PA in, LPs answering Peapods, donation-funded supply).  
- Then `poke()` lands the whole pool — size is depth, not $700k.

## Next live order

1. Deploy pool + Morpho auth (hot)  
2. `gasPark` ≥ $1M (scale toward $14M cap)  
3. PA reallocate / LP depth when available  
4. `poke` → Landing  
