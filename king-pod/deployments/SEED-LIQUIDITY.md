# feat/seed-liquidity — Micro-Seed Calibration

**PR:** `#78` · **Doctrine:** concentrated liquidity snaps $1 — not fat TVL.

## Why micro works

Uniswap V3 tight band (≈ **0.999–1.001**) around the peg gives **2,000×–4,000×** capital efficiency vs full-range.  
**$500–$1,000** eUSD/USDC in that band ≈ multi-million Uniswap V2 depth **at $1.00**.

## Minimal preflight

| Leg | Target |
|-----|--------|
| Treasury float | **≥ $990k eUSD** on hot (after 1M machine) |
| Pool micro-seed | **$500–$1,000** eUSD + matching USDC · tight ticks |
| Base Maker PSM | **Dust USDC** already WIRE-seeded on `0xfFEd…4977` |

## Scripts

```bash
npm install

# Step 1 — Micro-seed Base eUSD/USDC at $1 (default $1000, ±0.1% ticks)
# Requires matching USDC on hot. RESERVE_FLOOR keeps ≥990k eUSD.
npx hardhat run scripts/seedEthPool.ts --network base

# Step 2 — PSM dust (no-op if already reserved)
SKIP_IF_RESERVED=1 npx hardhat run scripts/seedBasePsm.ts --network base
```

### Env knobs

| Var | Default | Notes |
|-----|---------|-------|
| `EUSD_AMOUNT` | `1000` | Cap **1000** (micro max) |
| `USDC_AMOUNT` | = eUSD | 6dp match |
| `PAIR` | `USDC` | true $1 peg snap (prefer over WETH) |
| `FEE` | `500` | 0.05% |
| `TICK_WIDTH` | `10` | ≈ ±0.1% |
| `RESERVE_FLOOR` | `899000` | post-1M hot holds 900k; refuses seed if float would breach |
| `SKIP_IF_RESERVED` | — | PSM skip when reserve > 0 |

## Status

| Layer | Status |
|-------|--------|
| Treasury float | ✅ **900k eUSD** on hot — micro ≤$1k keeps ≥**$899k** |
| Peg pool (Base eUSD/USDC) | Micro-seed script ready — fire when hot holds **$500–$1k USDC** match |
| Base USDC PSM | ✅ WIRE dust live (`0xfFEd…4977`) |
