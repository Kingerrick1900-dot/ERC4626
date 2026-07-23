# Sovereign CDP — Healthy + Self-Liq — LIVE

## Canonical vault (use this)
| Piece | Address |
|--|--|
| **Elepan CDP** | `0x46b1D159b3a2694e7b70F550b7d5dEf6df451174` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Cold treasury / fee | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Self-liq | `selfLiquidate()` when `liquidatable()` (HF &lt; 150%) |

## Position
| Field | Value |
|--|--|
| Collateral | **25.2M** Elepan |
| Debt | **13M** eUSD |
| HF | **~1.938** (floor 1.55 / LR 1.50) |
| Landing eUSD | **13M** |
| Hot eUSD | **0** |

## Path taken
1. Top-up +5M Elepan on prior vault `0xcdA6…` → HF ~1.94  
2. Deploy Access-Clause vault with `selfLiquidate`  
3. `close` old → redeposit 25.2M → `mintTo(Landing, 13M)`

## Superseded
`0xcdA6Ee292B4A7a02CF2C7Ff5d8Bfa971ac5c3A27` — closed (coll=0, debt=0). Do not reuse.
