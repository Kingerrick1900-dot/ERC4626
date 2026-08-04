# Atomic DEX Flash Router — stop Morpho borrow queue

**Status:** LIVE on Base  
**Router:** `0xbd92dA50a5B4fdFbf02892321dF662F5FC388D6B`  
**Law:** Liquid USDC from **Base DEX** in one block. No PA/idle/borrow-queue polling as primary.

## Contract

`CrownAtomicDexFlashRouter` · deployed hot tx (see `broadcast/FireDexFlashRouter.s.sol/8453/`)

| Mode | What it does |
|--|--|
| `extractUsdc` | Pull free RSS → Aerodrome swap → USDC to **Landing** |
| `flashUnwindExtract` | Morpho flash → repay debt → free RSS → DEX sell to repay flash → leftover USDC to Landing |

Elepan denylist hardcoded. Morpho borrow idle / foreign maxIn **not consulted**.

## Live DEX (Base)

| Pool | Address | USDC reserve (live) |
|--|--|--|
| Aerodrome RSS/USDC volatile | `0x2C4F14744B8b3D087b768D0764d983Acb46d537a` | **~$1** |

Router + factory: `0xcF77…4E43` / `0x420D…40Da`  
Morpho flash inventory (USDC on Morpho): large — flash **source** is fine; **DEX sink** is the ceiling.

Honest gate: `flashUnwindExtract` **reverts `Depth()`** until Aerodrome USDC reserve ≥ debt (~$700k) + minLanding.  
`extractUsdc` can still pull **dust-sized** USDC from current ~$1 reserve (probe).

## Fire

```bash
# Quote / dry
python3 king-pod/script/FireDexFlashRouter.py --dry

# Deploy router
python3 king-pod/script/FireDexFlashRouter.py --fire --mode deploy

# Direct DEX extract (size to depth)
python3 king-pod/script/FireDexFlashRouter.py --fire --mode extract \
  --router 0x... --rss-in 1000000000000000000000 --min-usdc 1

# Flash-unwind (will Depth-revert while pool ~$1)
python3 king-pod/script/FireDexFlashRouter.py --fire --mode unwind --router 0x...
```

## Scanner shift

`ScanAllRails.py` primary auto-fire is now **DEX extract** (R10), not Morpho R2/R3 borrow.
Bundler3 borrow pack demoted. Aero auto-fire only when `dexUsdcReserve >= ask` OR King sets `DEX_DUST_OK=1` for depth-limited extract.
