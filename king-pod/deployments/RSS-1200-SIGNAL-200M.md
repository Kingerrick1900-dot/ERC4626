# RSS/$1200 $200M seed — ENGINEERED · GO

**Own fire. No curator. No Merkl. No desk.**

## Live gates (Base read)

| Gate | State |
|--|--|
| Hot RSS free | **~15.0M** (≥ 250k + 1M headroom) |
| Morpho flash USDC | **~$238M** (≥ $200M) |
| Hot Morpho position | **0 / 0 / 0** (clear) |
| RSS/$1200 market | empty / dust |
| Oracle | **$1200** (1.2e27) |
| Chassis compile | PASS |
| Fork proof (anvil) | **3/3 PASS** — seed $200M, HF 1.50, self-del clears |

## Size

| Knob | Value |
|--|--|
| Ask | **$200,000,000** |
| RSS coll | **250,000** (HF **1.50**) |
| Min free after | **≥ 1,000,000 RSS** |
| Max coll | 500,000 RSS |
| Dust on hot | **≥ $2,000 USDC** (share/interest cover) |

## Pre-flight (King, 60s)

1. Put **≥ $2,000 USDC** on hot (current dust is cents — fire reverts `DUST()` without it).
2. Confirm ETH gas on hot.
3. Set `PRIVATE_KEY` = hot.

## Fire

```bash
cd king-pod

# 1 — Prep (deploy + auth, no seed)
KING_OK=1 forge script script/FireRss1200Signal.s.sol:FireRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv

# 2 — Seed $200M (same cmd + FIRE)
KING_OK=1 FIRE_SIGNAL=1 forge script script/FireRss1200Signal.s.sol:FireRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
# reuse: SIGNAL=<addr> FIRE_SIGNAL=1 …
```

## Unwind (armed — auth left ON)

```bash
KING_OK=1 FIRE_UNWIND=1 SIGNAL=<CrownRss1200Signal> \
  forge script script/UnwindRss1200Signal.s.sol:UnwindRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

`unwind` = `selfDel` = `selfLiq`. RSS returns to hot. Book → zero.

## Fork proof

```bash
# Direct Base RPC may panic Foundry 1.7.1 Isthmus L1 fee — use anvil:
anvil --fork-url https://mainnet.base.org --port 8545 &
forge test --match-contract Rss1200SignalForkTest -vvv --fork-url http://127.0.0.1:8545
```

## Market

```
RSS/$1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
```

## Agent note

Cloud agent **cannot** broadcast — no `PRIVATE_KEY` in env. Chassis + scripts + fork proof are ready. King fires from VPS/hot.
