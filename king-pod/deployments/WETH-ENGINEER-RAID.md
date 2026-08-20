# WETH engineer → idle raid (LIVE)

**Status:** seed + raid **FIRED on Base**. Protocol life: open WETH equity door armed.

| Piece | Address |
|--|--|
| WETH seed | `0x60C452855eaedCD6917c2A3dDbd21678Ba390679` |
| Idle raid | `0x0d1861b59cc613CC09C8E9b1Ab419a98Bd30fD25` |
| Escrow RSS | **5,000,000** (+20% sweetener) |
| WETH sink | hot `0x6708…a7d1` |
| Morpho auth | **true** |
| WETH/USDC idle | ~**$9.87M** |

## Secure / maintain

1. Fillers bring WETH → hot (seed life).
2. When hot WETH ≥ ~360: `raid(wethIn, 700_000e6)` → Landing.
3. Do not rematch RSS/$1200 for payroll. Do not burn gas on optics.

## Filler

```text
weth.approve(0x60C452855eaedCD6917c2A3dDbd21678Ba390679, amt)
seed.fill(amt)   // WETH → hot, RSS+20% → filler
```

Quote: 360 WETH → ~833.8 RSS (sweetener included).

## Raid (after WETH on hot)

```bash
FIRE=1 RAID=1 ESCROW_RSS=0 \
  SEED=0x60C452855eaedCD6917c2A3dDbd21678Ba390679 \
  RAID_MACHINE=0x0d1861b59cc613CC09C8E9b1Ab419a98Bd30fD25 \
  WETH_IN=360000000000000000000 USDC_OUT=700000000000 \
  forge script script/FireWethEngineerRaid.s.sol:FireWethEngineerRaid \
  --rpc-url https://mainnet.base.org --broadcast --slow
```
