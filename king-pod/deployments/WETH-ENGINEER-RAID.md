# WETH engineer → idle raid / permissionless TAKE (LIVE seed+raid)

**Doctrine:** Raid WETH/USDC idle. No rematch theater. Equity → borrow → Landing.

| Piece | Address | State |
|--|--|--|
| WETH seed | `0x60C452855eaedCD6917c2A3dDbd21678Ba390679` | **LIVE** — 5M RSS escrowed, +20% sweetener, sink=hot |
| Idle raid | `0x0d1861b59cc613CC09C8E9b1Ab419a98Bd30fD25` | **LIVE** — Morpho `isAuthorized(hot,raid)=true` |
| TAKE (`CrownTakeWethIdle`) | *deploy with hot key* | Permissionless `poke()` when equity + idle ready |
| WETH sink | hot `0x6708…a7d1` | Needs ≥ ~380 WETH for $700k @ 86% LLTV |
| WETH/USDC idle | Morpho market | ~**$10M+** (reallocatable larger) |

## Physics (frozen)

- Matched RSS/$1200 book ≠ idle cash. Collateral capacity ≠ withdrawable USDC.
- 14% LLTV law: flash WETH → borrow → buyback needs ~14% equity buffer. Signal-slice alone cannot fund Landing while closing flash.
- **Working path:** WETH equity on hot → Morpho WETH/USDC borrow → Landing.

## Secure / maintain

1. Fillers (or wrap) put WETH on hot via seed:
   ```text
   weth.approve(0x60C452855eaedCD6917c2A3dDbd21678Ba390679, amt)
   seed.fill(amt)   // WETH → hot, RSS+20% → filler
   ```
2. Live-deploy TAKE (one-time, hot key):
   ```bash
   FIRE=1 forge script script/FireTakeWethIdle.s.sol:FireTakeWethIdle \
     --rpc-url https://mainnet.base.org --broadcast --slow
   ```
   Script deploys TAKE, Morpho-auths it, `WETH.approve(take, max)` from hot.
3. Anyone when `ready()==true`: `take.poke()` → Landing **+$700,000** (hard gate).

## Anvil prove (done)

Permissionless keeper `poke()` → Landing delta **700_000e6**. Fixed: poke pulls full equity (Morpho double-truncation made exact-ceil under-borrow by ~0.39 WETH).

```bash
# Fork anvil, then cast-create TAKE + wrap equity + poke from second key
# Or: forge script script/ProveTakeWethIdle.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Raid (manual king path, already LIVE)

```bash
FIRE=1 RAID=1 ESCROW_RSS=0 \
  SEED=0x60C452855eaedCD6917c2A3dDbd21678Ba390679 \
  RAID_MACHINE=0x0d1861b59cc613CC09C8E9b1Ab419a98Bd30fD25 \
  WETH_IN=380000000000000000000 USDC_OUT=700000000000 \
  forge script script/FireWethEngineerRaid.s.sol:FireWethEngineerRaid \
  --rpc-url https://mainnet.base.org --broadcast --slow
```

## Do not

- Rematch RSS/$1200 for payroll / Merkl waits / empty-vault realloc bots
- Burn gas without WETH equity path to Landing
- Store hot keys in repo
