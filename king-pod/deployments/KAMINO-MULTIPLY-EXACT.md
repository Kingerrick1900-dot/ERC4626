# EXACT Kamino Multiply — Landing USDC must hit

## Apology / correction

Prior `CrownVenusMultiply700k` was **Morpho rematch** (repay→borrow same book). That is **not** Kamino.  
Kamino: **flash debt → swap to collateral → supply collateral → borrow debt to repay flash**.

**No live fire** went out for Venus rematch. Hard law restored: **do not fire unless Landing USDC hits.**

## Exact steps (Kamino docs)

1. User equity (WETH deposit)
2. Flash USDC
3. Swap USDC → WETH (deep Aero WETH/USDC `0xcDAC…C43`)
4. `supplyCollateral` all WETH on Morpho WETH/USDC `0x8793…1bda` (idle ≥ **$7M**)
5. Borrow USDC = flash + wantLanding
6. wantLanding → **Landing**; flash amount repays Morpho flash
7. Seed = WETH coll position + USDC debt

## Why not RSS/$1200 book

That book is **self-matched ~0 idle**. Kamino borrow-to-repay needs **foreign USDC idle**. WETH/USDC has it.

## Free RSS

Free RSS is real equity value, but there is **no RSS/WETH pool**. Exact Kamino collateral on this market is **WETH**.  
Bridge free RSS → WETH is separate engineering (depth past Aero RSS/USDC $0.67). Until WETH equity is on hot (wrap / bridge), fork proves with WETH equity.

## Fork

```bash
cd king-pod
FOUNDRY_DISABLE_NIGHTLY_WARNING=1 forge test --match-contract KaminoMultiplyFork -vv --fork-url $BASE_RPC_URL
```

`test_kamino_exact_landing_hits_700k` — **Landing Δ = $700,000** required to PASS.

## Live fire gate

```bash
# Will revert unless Landing USDC increases by WANT_LANDING
FIRE=1 EQUITY_WETH=... FLASH=700000000000 WANT_LANDING=700000000000 \
  forge script script/FireKaminoMultiply.s.sol:FireKaminoMultiply \
  --rpc-url $BASE_RPC_URL --broadcast
```

Contract + script both revert if Landing miss.
