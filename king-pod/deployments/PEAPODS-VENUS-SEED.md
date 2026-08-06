# Peapods + Venus number engineering

King order: engineer numbers like live protocols — flash atomic, no funder wait.

## 1) Peapods self-lend (`CrownPeapodsMorphoSeed`)

Flash USDC → supply Morpho RSS/$1200 → borrow same vs existing RSS coll → repay flash.  
**Result:** matched book grows, 100% util, no external supplier.

| Seed | Supply Δ (fork) | Borrow Δ |
|--|--|--|
| $700k | ≥ $700k (interest bump ~$830k observed) | ≥ $700k |
| $3M | ≥ $3M | ≥ $3M |

LTV headroom on hot ≈ **$3.28M** (cap for this seed).

```bash
SEED_USDC=700000000000 forge script script/FirePeapodsSeed.s.sol:FirePeapodsSeed \
  --rpc-url https://mainnet.base.org --broadcast
```

## 2) Venus WETH multiply → Landing USDC (`CrownVenusWethMultiply`)

Flash WETH + equity WETH → Morpho supply → borrow USDC → Aero buy-back flash WETH → **residual USDC → Landing**.

| Equity | Flash | Borrow | **Landing Δ (fork)** |
|--|--|--|--|
| **500 WETH** | 100 WETH | $900k | **~$693,349 USDC** |

Zero equity cannot clear WETH flash at 86% LLTV (same as Venus).

## Scoreboard

- Peapods: engineers **Morpho book size** (position/TVL seed).  
- Venus: engineers **Landing USDC** when WETH equity is posted (protocol multiply math).
