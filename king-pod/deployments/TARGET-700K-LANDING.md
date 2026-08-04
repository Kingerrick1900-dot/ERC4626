# TARGET: $700k USDC → Landing

**Focus:** `Landing 0x5Adc…2357` += **$700,000 USDC**. Not idle commentary.

## Free RSS first — what it does

| Step | Result |
|--|--|
| Flash repay ~$700k Morpho debt → withdraw 1.2M RSS → redeem yRSS → repay flash | Hot holds **~10.03M RSS** free · Morpho debt **0** |
| Landing USDC after free | **Unchanged** (~$3.40) — free unlocks **RSS ammo**, not the $700k |

So: free first = correct prep. It does **not** by itself deliver the $700k. Then we use that RSS as Morpho collateral to **borrow $700k → Landing**.

## Collateral vs $700k (ammo is not the bottleneck)

| Oracle | RSS needed @ ~70% LTV for $700k borrow |
|--|--|
| $1 (old market) | ~**1.0M RSS** |
| $1200 (king market) | ~**833 RSS** |

Free pile after unwind ≈ **10.0M RSS** — far above either. **RSS size is enough.**

## The $700k machine (hard-coded Morpho)

```text
1) FREE  — unwind current ~$700k loop → all RSS on hot
2) POST  — supplyCollateral (enough RSS for $700k + buffer) on RSS/USDC market
3) BORROW — morpho.borrow(700_000e6) → Landing
4) STOP  — no yRSS recycle
```

Bundler3 pack already encodes post+borrow→Landing. Ask size: **700000e6**.

## Order of fire (King GO)

1. **Free now** — `DeployAndChunkFreeRss` / flash-free against live ~$700k book  
2. **Borrow $700k** — same block or next, the moment the chosen RSS/USDC market can fill the ask (Bundler3 / Option C / SpoilFire)  
3. Confirm Landing USDC ≥ **$700,000**

Scoreboard = Landing USDC. Nothing else.
