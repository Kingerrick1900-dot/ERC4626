# RSS ← Elepan gold / reserves fork

**Status: CODE FORK ONLY — FROZEN.** No wrap, mint, or Morpho fire until King GO.

## What was forked

| Elepan | RSS fork |
|--------|----------|
| `CrownGold` (kXAU) | `CrownRssGold` (kRSSG) |
| (manual mint) | `CrownRssGoldWrap` — lock RSS → mint kRSSG |
| `CrownGoldCdp` (Scroll) | `CrownRssGoldCdp` (Base) — lock kRSSG → mint eUSD → Landing |
| `CrownBoundReservesGate` (USDC) | `CrownRssBoundReservesGate` — `balanceOf(RSS)` attest |

## Contracts (repo)

- `king-pod/src/CrownRssGold.sol`
- `king-pod/src/CrownRssGoldWrap.sol`
- `king-pod/src/CrownRssGoldCdp.sol`
- `king-pod/src/zk/CrownRssBoundReservesGate.sol`
- Deploy (dry default): `script/FireRssElepanGoldFork.s.sol`

## Deploy (King only)

```bash
KING_OK=1 FIRE_RSS_GOLD_FORK=1 PRIVATE_KEY=0x… \
  forge script script/FireRssElepanGoldFork.s.sol:FireRssElepanGoldFork \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

After deploy: set eUSD minter → CDP (separate King step) before any `mintToLanding`.

## Freeze

No RSS locked. No CDP mint. No Morpho seed from this fork until King commands.
