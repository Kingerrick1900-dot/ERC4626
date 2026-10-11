# FIRE — Parallel RSS/USDC Capacity (LLTV 38.5%)

**Mode:** FIRE · Base · ZK mandatory  
**Status:** **LIVE**  
**Doctrine:** Legacy SOV `0x1293…` untouched · RSS never sold · Safe pending King · HOT operator

---

## Parallel market

| Field | Value |
|--|--|
| **Market id** | `0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134` |
| Loan / coll | USDC / RSS |
| Oracle | CrownOracle `0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| **LLTV** | **38.5%** (`385000000000000000`) — under 50%, Morpho-enabled |
| Utilization | **0%** (empty book) |
| createMarket tx | [`0x7d6d8322…da6a`](https://basescan.org/tx/0x7d6d83229b90a9e6f3e738a4622da10cb32cf96f8d2909039c1fb4567e61da6a) |

## Parallel Gate

| Field | Value |
|--|--|
| **CrownGateV2** | `0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9` |
| Deploy tx | [`0x2383cfaf…80f3`](https://basescan.org/tx/0x2383cfaff8f4c804ee6eaf452e43c222458cbe18575fcee9dcc40fd5ba5f80f3) |
| setOperator(HOT) | [`0x20dc0ab0…46dc`](https://basescan.org/tx/0x20dc0ab03ef85dab84f1e7279cf342101c1e979a2c7e814f12613b5361bd46dc) |
| initiateKingTransfer(Safe) | [`0xe2f54f5a…c0a6`](https://basescan.org/tx/0xe2f54f5a1cd8b3aa1694befcbddaa90c2e74d1051ff7fa2509f1a6b378b9c0a6) |
| king | HOT `0x6708…a7d1` (until Safe accepts) |
| pendingKing | Safe `0x23590FEb…eac0` |
| operator HOT | **true** |
| zkGate | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` |
| paused | false |

## Legacy (untouched)

| Field | Value |
|--|--|
| Market | `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b` |
| Gate | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| Position | borrowShares `2999964634431372816` · collateral `222521940922706875000000` RSS |

---

## Next

1. **Safe 2-of-3:** `acceptKingship()` on parallel Gate `0x8Bbd…B2B9`  
2. Seed USDC supply into parallel market when commanded  
3. Post RSS / borrow under ZK (`isProven(Safe)`)

```
FIRE_PARALLEL_CAPACITY=1
PARALLEL_MARKET=0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134
PARALLEL_GATE=0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9
PARALLEL_LLTV=385000000000000000
TX_CREATE=0x7d6d83229b90a9e6f3e738a4622da10cb32cf96f8d2909039c1fb4567e61da6a
TX_GATE=0x2383cfaff8f4c804ee6eaf452e43c222458cbe18575fcee9dcc40fd5ba5f80f3
NEXT=SAFE_ACCEPT_KINGSHIP
```
