# Seed Land $700k — borrow > flash → Landing

## Path

```
buffer want USDC (from hot) + flash F
→ unmatched supply(F + want)     // engineer idle
→ supplyCollateral(free RSS)
→ borrow(F + want)               // borrow > flash
→ want → Landing ; F → repay flash
```

Buffer is **not burned** — it becomes king's Morpho supply shares. Landing receives Circle USDC.

## Why buffer

Empty RSS/$1200 book has ~0 idle. Supplying only the flash makes idle = flash, so borrow cannot exceed flash and Landing surplus is 0. Buffer `want` raises idle to `F+want`.

## Defaults

| Param | Value |
|-------|-------|
| Market | `0x41c08085…` (RSS/$1200) |
| want / F | `$700,000` each |
| borrow | `$1,400,000` |
| RSS coll | `5,000` (~$6M @ $1200) |

## Fork

```bash
FOUNDRY_DISABLE_NIGHTLY_WARNING=1 forge test --match-contract SeedLandFork -vv --fork-url $BASE_RPC_URL
```

## Live gate

Hot must hold ≥ `want` USDC buffer. Script reverts `NO_BUFFER_USDC` otherwise (hot ~$0.70 today).

```bash
FIRE=1 forge script script/FireSeedLand.s.sol:FireSeedLand --rpc-url $BASE_RPC_URL --broadcast -vvvv
```

Hard gate: `LANDING_DID_NOT_HIT` if Landing Δ < want.
