# Protocol lock — EXACT Kamino Multiply (Landing must hit)

Prior rematch chassis was wrong. **Kamino is flash → swap to coll → supply → borrow debt to repay.**

See `KAMINO-MULTIPLY-EXACT.md`.

1. User equity (WETH)
2. Flash USDC
3. Swap USDC → WETH (deep Aero)
4. Supply WETH on Morpho WETH/USDC (foreign idle)
5. Borrow flash + want; **want → Landing**; flash repaid
6. **Do not live-fire unless Landing USDC Δ = want**

## Chassis

| Contract | Role |
|----------|------|
| `CrownVenusMultiply700k.sol` | **Primary — King's command** |
| `CrownSeamlessMission.sol` | Seamless settle companion |
| `CrownMissionComplete.sol` | Proto/unlock companions |

```bash
cd king-pod
FOUNDRY_DISABLE_NIGHTLY_WARNING=1 forge test --match-contract VenusMultiply700kFork -vv --fork-url $BASE_RPC_URL
```

## Free tokens — IN USE

| Bag | Amount | Action |
|-----|--------|--------|
| **Free RSS on hot** | **~9.76M** | **Used as Multiply equity** (~1k in fork; ~758 min @ oracle) |
| Morpho posted coll | **220k RSS** | Untouched unless King says `FREE THE BOOK` |

## Depth

Aero RSS/USDC live ≈ **$0.67**. Engineered past: Morpho idle manufacture inside the flash.  
Not waiting on pool depth. Not passing the buck.

## Scribe

- Multiply **$700k closes** with zero hot USDC prefund — seed = position (free RSS posted)  
- Landing Circle USDC surplus = **$0** on self-matched rematch today (flash consumes manufactured idle)  
- Landing Δ = **$700k** when foreign/PA idle lets Venus surplus ≥ ask — still not “USDC buffer on hot”
