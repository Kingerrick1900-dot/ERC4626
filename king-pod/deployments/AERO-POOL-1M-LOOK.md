# Aero RSS/USDC — engineer $1M LOOK (live ≈ $0.67)

Pool: `0x2C4F14744B8b3D087b768D0764d983Acb46d537a` (Base Aerodrome RSS/USDC).

## Fact

Live USDC reserve is ~**$0.67**. Router `addLiquidity` / UniV2 `mint` fails USDC-only because
`liquidity = min(amount0 * ts / r0, amount1 * ts / r1)` → USDC-only → **0 LP**.

## Engineer

Chassis: `CrownAeroPool1MSeed.sol` — `transfer(pool, usdc)` + `sync()` (no matched RSS mint required).

| Mode | Call | USDC source | After tx |
|------|------|-------------|---------|
| **Ephemeral LOOK** | `lookEphemeral(≥1e12, rssMax, buffer)` | Morpho flash + ~2–3% King buffer | Peak ≥ $1M in-tx; RSS reclaim + buffer repay flash |
| **Persist LOOK** | `lookPersist(≥1e12)` | King USDC | Pool keeps ≥ $1M (costs the USDC) |
| **Persist + flash** | `lookPersistFlash(≥1e12)` | Flash inflate + prefund repay on chassis | Pool keeps flashed USDC |

### Why ephemeral needs a buffer

After stuffing $1M, selling RSS cannot extract 100% (constant product + Aero ~0.3% fee).
With ~9M free RSS, reclaim ≈ **$980k**. Gap ≈ **$20k** must sit on the chassis (King buffer / `deal` in fork) or Morpho repay reverts.

## Fork proof

```bash
forge test --match-contract AeroPool1MSeedFork -vvv
```

Proven:
- Ephemeral peak **$1,000,000.667** (from $0.67)
- Persist / persist-flash pool USDC **≥ $1M** after tx

## Live fire

**Do not live-fire** unless optics GO is explicit. Ephemeral burns free RSS into the pool; persist costs real ≥ $1M USDC.
Landing scoreboard is not the win condition for optics — honest residual ≈ $0 / fee dust.
