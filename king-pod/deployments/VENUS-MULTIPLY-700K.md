# King's command — Venus / Kamino Multiply $700k (free RSS)

## Command

1. **Size:** $700k only  
2. **Equity:** free RSS already on hot (~9.76M) — do **not** wait on Aero depth  
3. **Pattern:** Venus `LeverageStrategiesManager` / Kamino Multiply / Pendle PT flash  
4. **Close:** debt on router repays Morpho flash (Seamless/Venus law)  
5. **Depth:** engineered in-tx via Morpho `repay` idle manufacture — empty pool is not a veto  

## Mechanics

```text
free RSS equity → flash $700k USDC → repay (engineer idle) → borrow to router (close)
seed = Morpho position (RSS coll posted + rematched debt)
Landing USDC surplus = max(0, idle − flash) → 0 on self-matched book today
```

Research bottom line stands: **seed is the position**, not leftover flash USDC.  
Landing Circle USDC Δ hits $700k when foreign/PA idle lets Venus surplus ≥ ask.

## Chassis

`CrownVenusMultiply700k.sol`

```bash
cd king-pod
FOUNDRY_DISABLE_NIGHTLY_WARNING=1 forge test --match-contract VenusMultiply700kFork -vv --fork-url $BASE_RPC_URL
```

## Free tokens

| Bag | Use |
|-----|-----|
| ~9.76M free RSS on hot | **Yes — equity for Multiply** (~1k RSS used in fork; ~758 min @ oracle) |
| 220k Morpho posted coll | **No free unless King says** `FREE THE BOOK` |

## Depth

Live Aero RSS/USDC ≈ **$0.67**. That is not the blocker we stop on.  
Lending depth for Multiply is manufactured with the flash (`repay` → idle).  
Aero flash-stuff remains available for swap optics (`CrownAeroPool1MSeed`) — separate from this Multiply seed.
