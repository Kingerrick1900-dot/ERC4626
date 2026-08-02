# eUSD exit leg — liquidity + LIVE clear

## Liquidity status (pre-fire)

| Surface | USDC | eUSD |
|--|--|--|
| Uni eUSD/USDC `0x5f3f…063Fc` | **$0.20** (`200000`) | **0.2** |
| Scroll PSM | **not deployed / no reserves** | — |
| Hot | **0** | **~100,001** |
| Scroll Landing | **$0.53** (post-completer) | 0 |
| Cold | — | **~545,168** (keep) |

**Depth wall:** pool can clear ≈ **$0.19** eUSD before $0.01 floor. Not $100k.

## Script fix

`FireScrollEusdExit` — depth-aware pool swap (not completer, not false 100k):
- Caps `swapEusd` to `poolUsdc - $0.01`
- Pays **Scroll Landing**
- Direct UniV3 pool swap (no missing ROUTER)

## LIVE clear

| | |
|--|--|
| Sold | **0.19 eUSD** |
| Landing Δ | **+97,285** raw USDC (~**$0.097**) |
| Landing after | **625,062** (~**$0.63**) |
| Hot eUSD left | **~100,000.91** |
| Pool USDC after | **~102,715** (~$0.10 floor) |

Broadcast: `king-pod/broadcast/FireScrollEusdExit.s.sol/534352/run-latest.json`

## To clear the full 100k tranche

Pool (or PSM) needs **≥ ~$100k USDC** depth, then same exit script with no code change — `SWAP_EUSD` / auto depth cap scales up.
