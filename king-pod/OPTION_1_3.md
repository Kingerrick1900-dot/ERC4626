# Corrected Option 1+3 (protocol build — not get-rich-quick)

## Wrong example (do not execute)
Flash $1M → swap half → $1M cash LP → borrow $700k → repay $1M  
**Fails:** $700k < $1M.

## Correct Option A with 10M liquid RSS @ $0.05
```
rssUsd = 10e6 * 0.05 = $500,000
F_max ≈ $1.16M  (from 0.7*(rssUsd+F) ≥ F+premium)
$1M flash: OK on collateral math
```

Loop:
1. Prefund Pod with **≥ ~$500 USDC** (Aave premium ~0.05% of $1M)
2. King approve **10M RSS** → Pod
3. `pod.bootstrap(10_000_000e18, 1_000_000e6)`
4. flash → all USDC to sUSDC → LP(RSS,sUSDC) → collateral → borrow face → repay face+premium
5. Liquid left **11M RSS**
6. Attract lenders into **this** sUSDC → idle > 0 → Phase C 12%

## Gate
Cannot finish Aave $1M until **~$500 USDC** sits on the Pod/King for premium. Gas alone is not enough.
v1 Pod (20.979B RSS / $60k) stays as-is — new stack required (pool ratio cannot absorb $1M with only 10M RSS).
