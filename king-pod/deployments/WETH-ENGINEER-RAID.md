# WETH engineer → idle raid (no guesswork)

**Freeze path:** Engineer **WETH equity**, then Morpho WETH/USDC borrow → Landing.  
Elite shape: Kamino/Venus/LI.FI path C — seed first, then loan against a book that already has idle.

## Why this works

| Fact | Live |
|--|--|
| WETH/USDC idle | ~$10M |
| Hot WETH | ~0 — so we **engineer** it |
| Free RSS | ~14.6M — bait for open fill / desk |
| Rematch RSS/$1200 alone | Landing Δ $0 (fork-proven) |

## Two ways we engineer ≥351 WETH

1. **Permissionless WETH seed** — anyone `fill(weth)` → WETH to hot, RSS+20% to filler (oracle-priced).  
2. **RSS/WETH desk** — lender `fund(weth)` → king `draw` locks RSS, pulls WETH (loan, not sale).

Then **`CrownWethIdleRaid.raid`** posts WETH on Morpho and sends USDC to Landing.

## Fire

```bash
# 1) Deploy raid + seed + desk; escrow 5M RSS into open WETH seed
KING_OK=1 FIRE=1 ESCROW_RSS=5000000000000000000000000 \
  forge script script/FireWethEngineerRaid.s.sol:FireWethEngineerRaid \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv

# 2) Filler (any wallet with WETH):
#    weth.approve(SEED, amt); seed.fill(amt);

# 3) When hot WETH ≥ 360:
KING_OK=1 FIRE=1 RAID=1 ESCROW_RSS=0 SEED=0x… RAID_MACHINE=0x… \
  WETH_IN=360000000000000000000 USDC_OUT=700000000000 \
  forge script script/FireWethEngineerRaid.s.sol:FireWethEngineerRaid \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

## Fork

```bash
forge test --match-contract WethEngineerRaidFork -vv --fork-url https://mainnet.base.org
```

Hard law: Landing Δ must equal ask or full revert.
