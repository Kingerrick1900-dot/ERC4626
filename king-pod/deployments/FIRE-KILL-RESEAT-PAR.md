# FIRE — Kill $3M · Reseat PAR

**Mode:** FIRE · Base · **LIVE**  
**Doctrine:** RSS stays collateral · no $3M re-draw · real ceiling **$4.28B** · seed then borrow

---

## Result

| Field | Value |
|--|--|
| **Status** | **$3M DEAD · RSS ON PAR** |
| Killer | [`0x7273ffE28a0aa8323d5c8F3D23793a7fA19ebD17`](https://basescan.org/address/0x7273ffE28a0aa8323d5c8F3D23793a7fA19ebD17) |
| Owner | HOT |
| Deploy | [`0xb5e01308…ec0f`](https://basescan.org/tx/0xb5e01308fb68189e3746ed5c78c690689f376b477108f065298ab6000b5bec0f) |
| `killAndReseat()` | [`0x3d955515…ebdf`](https://basescan.org/tx/0x3d955515ff45ac7d3bc33ab3a18b1949157cd634503cd5bad17d3794530eebdf) |

## Positions (live)

| Book | borrowShares | collateral |
|--|--:|--:|
| Elephant SOV | **0** | **0** |
| Killer PAR `0x1bfd…` | **0** | **`222521940922637943194240`** (~222,521.94 RSS) |
| SOV market supplyAssets | **2** wei (circular LP written off) | borrow **0** |
| PAR market idle | **$0** | no draw |

| Oracle | |
|--|--|
| owner | HOT |
| price | `5e28` ($50,000) |

## How the $3M died

Elephant debt and Kingdom fire LP (KF+CF = 100% of SOV supply) were a matched circular book.  
Dust-oracle full seize repaid **2 wei** USDC; Morpho **bad-debt** cleared the residual ~$3.005M against that own LP. No external supplier harmed. No $3M re-borrow.

Flash size: **$0.10** (tip cover), not $3M.

## Capacity (now)

```
222,521.94 RSS × $50,000 × 38.5% LLTV ≈ $4.28 Billion theoretical
fireable now = min($4.28B, PAR idle) = $0
```

**Next:** seed USDC idle into PAR `0x1bfd…`, then draw against the $4.28B ceiling.

```
FIRE_KILL_RESEAT_PAR=1
KILLER=0x7273ffE28a0aa8323d5c8F3D23793a7fA19ebD17
TX_KILL=0x3d955515ff45ac7d3bc33ab3a18b1949157cd634503cd5bad17d3794530eebdf
ELEPHANT_DEBT=0
PAR_COLL~=222521.94
PAR_BORROW=0
CEILING_USD~=4283547363
PAR_IDLE=0
NEXT=SEED_PAR_IDLE_THEN_DRAW
```
