# King Pod — Option A (Production Spec)

**Status:** Phase A — bootstrap machine. Not Morpho. Not team-cut from flashloan dust.

## Crown orders locked

| Item | Value |
|------|-------|
| Signer / gas payer | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| RSS | `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| USDC (Base) | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| RSS policy price | **$0.05** (oracle hard cap / fixed) |
| Liquid reserve | **21,000,000 RSS** remain in wallet |
| Bootstrap RSS | **20,979,000,000 RSS** (full supply minus liquid) |
| LLTV | **70%** |
| Core team cut | **12%** of *free borrowed USDC after Phase A* — not from flashloan residue |
| Flashlender | Balancer V2 Vault `0xBA12222222228d8Ba445958a75a0704d566BF2C8` |

## Forbidden handoff math (will not ship)

Any flow of the form:

- flashloan $5M → swap half → cash LP → borrow $3.5M → repay $5M → keep $420k/$500k cut  

**cannot close.** Max borrow at 70% LTV on a ~$5M cash LP is ~$3.5M; flashloan debt is $5M. Tx reverts. Scribe will not implement it.

## Option A — what ships (atomic)

```
1. Flashloan F USDC from Balancer
2. Supply all F → KingMoneyMarket → mint sUSDC
3. Add liquidity: RSS_amount + sUSDC → KingPair LP
4. Post LP as collateral (70% LLTV)
5. Borrow F (+ fee) USDC from KingMoneyMarket
6. Repay Balancer in full
7. LP + debt remain; free USDC ≈ 0
```

**Invariant:** `repay_to_balancer == flash + fee` and `HF >= 1` and `idle_USDC_after ≈ 0`.

## Phase C — 12% treasury allocation (locked policy)

**Only** after **net free USDC > 0** from *external* lenders (or a later solvent surplus — not Option A residue):

| Bucket | Share of free USDC | Example on $3.5M free |
|--------|--------------------|------------------------|
| Core team treasury | **12%** | $420,000 |
| Deployed capital | **88%** | $3,080,000 |

Suggested deploy mix of the **88%** (policy, not auto-executed in Phase A):

| Asset | Share of deployed |
|-------|-------------------|
| cbBTC | ~50% |
| Aave USDC | ~34% |
| PAXG | ~16% |

Until free USDC exists: **no team cut, no cbBTC/Aave/PAXG from bootstrap.**

## Oracle policy

- USDC = $1
- RSS = **$0.05** fixed (Crown policy), used only inside King Pod risk
- LP value = `rss_reserve * 0.05 + sUSDC_assets` (via ERC4626 convertToAssets)

## Success scoreboard (Phase A)

| Metric | Target |
|--------|--------|
| Flashloan debt | 0 |
| LP owned by position | > 0 |
| Money market supply ≈ borrow | ~F |
| Free USDC in King wallet from bootstrap | ~0 |
| Morpho | unused |

Phase B (Morpho / outside lenders) and Phase C (12% cut + yield deploy) are separate missions.
