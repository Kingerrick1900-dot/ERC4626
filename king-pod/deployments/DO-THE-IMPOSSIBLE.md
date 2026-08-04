# Do the impossible — open fill, not desk-wait

**King order:** Desk boil-down = engineer to fail. Do the impossible = force lasting Landing USDC from inventory + open market, not a named matcher prayer.

## Physics (no lies)

| Path | Lasting Landing USDC? |
|--|--|
| Morpho flash alone | **NO** — must repay same block |
| Bound proven $700k | Unlock only — credit pool still needs real USDC |
| Completer / Permit2 | **YES if** matcher brings USDC |
| eUSD→USDC DEX/PSM | Depth ≈ **$0** (cannot convert at size) |
| Aero RSS/USDC | Depth ≈ **$1** — dump forbidden at size |
| Foreign PA maxIn | **0** |
| Morpho RSS idle | ≈ **$1** |

Lasting USDC = **counterparty** or **convertible depth**. Flash reflection ≠ payroll.

## What we engineered instead of waiting

### 1) Permissionless seed (LIVE) — anyone fills

| | |
|--|--|
| Seed | `0x08DD633247F79740708d145A3A8964a8c9Ee501a` |
| Escrow | **5M RSS** (2M + 3M top-up) **LIVE** |
| Terms | **$1 par + 20% RSS sweetener** **LIVE** |
| Fill | `usdc.approve(seed, amt); seed.fill(amt)` → USDC **to Landing**, RSS to filler |

Any bot/LP/arb on Base — not Armitage-only. +20% is the bribe that makes capital show up.

### 2) Impossible machine **LIVE**

| | |
|--|--|
| Machine | `0xd3C59841818552F34599744cf4952B3d7760F41d` |

`CrownImpossibleUsdcMachine` — cold-or-revert Landing delta.

- `extractDex` — explicit only (loan≠dump); scales when Aero deepens  
- `flashFillExtract` — flash → seed fill → DEX repay when depth ≥ flash  

### 3) eUSD treasury rail

Hot eUSD → Landing (ops currency we already hold; not a market dump).

## Fire

```bash
python3 king-pod/script/FireImpossibleUsdc.py --fire --mode all
# filler (any wallet):
#   seed.fill(usdcAmount)
```

## Scoreboard

```
Landing_USDC ↑
seed.usdcRaised ↑
Elepan_untouched = true
desk_wait_primary = false
```
