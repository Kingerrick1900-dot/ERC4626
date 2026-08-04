# Bundler3 Atomic Pack — primary live executor (R8)

**Status:** Armed  
**Role:** Primary onchain executor when any liquidity rail greens  
**Scanner:** `ScanAllRails.py --auto-fire` → this pack for R2 / R3 / R4

## Addresses (Base)

| Contract | Address |
|--|--|
| Bundler3 | `0x6BFd8137e702540E7A42B74178A4a49Ba43920C4` |
| GeneralAdapter1 | `0xb98c948CFA24072e58935BC004a8A7b376AE746A` |
| Hot Morpho auth(GA1) | **true** (already set) |
| Landing (borrow receiver) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |

## Atomic bundle (one tx)

1. *(optional R3/R4)* `PublicAllocator.reallocateTo` — pull USDC into RSS market  
2. `GA1.erc20TransferFrom(RSS → GA1)`  
3. `GA1.morphoSupplyCollateral` on behalf of hot  
4. `GA1.morphoBorrow` → **Landing**

Elepan never in the bundle. No Aerodrome swap.

## Fire

```bash
# Dry
python3 king-pod/script/FireBundler3AtomicPack.py --dry --ask 500000

# Live R2 (Morpho idle ≥ ask)
FIRE=1 python3 king-pod/script/FireBundler3AtomicPack.py --fire --ask 500000

# Live R3 (foreign PA)
python3 king-pod/script/FireBundler3AtomicPack.py --fire --ask 500000 \
  --pa-vault 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61 \
  --pull-usdc 500000000000

# Auto: scan all rails → first green Bundler3 rail broadcasts
python3 king-pod/script/ScanAllRails.py --auto-fire --ask 500000
python3 king-pod/script/ScanAllRails.py --poll --interval 60 --auto-fire
```

Forge direct:

```bash
ASK_USDC=500000000000 COLL_RSS=800000000000000000000000 FIRE=1 \
  forge script king-pod/script/FireBundler3AtomicPack.s.sol:FireBundler3AtomicPack \
  --rpc-url $BASE_RPC --broadcast --slow
```

## Gates (revert if fail)

- `effectiveIdle >= ask` (market idle, or idle + PA pull)
- free RSS ≥ `COLL_RSS` (default 800k)
- LTV 70% buffer vs existing ~$700k debt + ask
- `isAuthorized(hot, GA1)`
- Landing delta ≥ ask after multicall
