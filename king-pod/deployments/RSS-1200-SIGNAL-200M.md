# RSS/$1200 $200M seed — ENGINEERED · GO

**Own fire. No curator. No Merkl. No desk. No $2k USDC buffer.**

Matched book: king is both sides. Interest owed = interest earned. Net USDC cost = **0**. Gas = **ETH only**.

## Live gates

| Gate | Need |
|--|--|
| Hot RSS free | ≥ 250k + 1M headroom (~15M live) |
| Morpho flash USDC | ≥ $200M (~$238M live) |
| Hot Morpho position | clear |
| Hot USDC | **not required** |
| Gas | ETH on hot |

## Size

| Knob | Value |
|--|--|
| Ask | **$200,000,000** |
| RSS coll | **250,000** (HF **1.50**) |
| Min free after | **≥ 1,000,000 RSS** |

## Fire

```bash
cd king-pod
./script/seed_ready.sh

KING_OK=1 FIRE_SIGNAL=1 forge script script/FireRss1200Signal.s.sol:FireRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

## Unwind

```bash
KING_OK=1 FIRE_UNWIND=1 SIGNAL=<CrownRss1200Signal> \
  forge script script/UnwindRss1200Signal.s.sol:UnwindRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

## Fork proof

```bash
anvil --fork-url https://mainnet.base.org --port 8545 &
forge test --match-contract Rss1200SignalForkTest -vvv --fork-url http://127.0.0.1:8545
```
