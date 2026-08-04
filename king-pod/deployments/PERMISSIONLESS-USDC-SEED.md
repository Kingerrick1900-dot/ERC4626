# Permissionless USDC seed — engineering, not desk-wait

**King order:** Desk/matcher boil-down = procedure to fail. Fix: open fill from inventory.

## What changed

| Old (fail mode) | New (engineer) |
|--|--|
| Wait Armitage / named matcher | **Anyone** can fill onchain |
| Hope theater | Escrow RSS → pay USDC to Landing → take RSS |
| USDC=$0 forever | Open market for USDC against real inventory |

## Contract

`CrownPermissionlessUsdcSeed`

- King escrows RSS  
- Filler: `fill(usdcIn)` — USDC goes **straight to Landing**, filler gets RSS (+ optional sweetener)  
- Par `$1` (`rssPerUsdc = 1e12`) · sweetener **+20%** RSS (max)  
- Escrow **5M RSS** · Elepan denylist  

## LIVE

| | |
|--|--|
| Seed | `0x08DD633247F79740708d145A3A8964a8c9Ee501a` |
| Impossible machine | `0xd3C59841818552F34599744cf4952B3d7760F41d` |
| See also | `DO-THE-IMPOSSIBLE.md` |

## Also

`MODE=eusd_landing` / `FireImpossibleUsdc --mode eusd` — relocate eUSD inventory to Landing treasury (ops currency we already hold; not a dump to market).

## Fire

```bash
# Max pressure (sweetener + escrow + machine + eUSD)
python3 king-pod/script/FireImpossibleUsdc.py --fire --mode all

# Fillers (any wallet with USDC):
#   usdc.approve(seed, amount)
#   seed.fill(amount)   # USDC → Landing, RSS ← filler (+20%)
```

## Physics (honest)

Open fill still needs **someone** with USDC — but that someone is **any** bot/LP/arb on Base, not one desk. That is market engineering. Named-desk RFQ as the whole op was the failure mode.
