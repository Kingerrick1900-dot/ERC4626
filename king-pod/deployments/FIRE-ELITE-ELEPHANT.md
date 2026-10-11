# FIRE — Elite Elephant Walked

**Mode:** FIRE · Base · **LIVE**  
**Doctrine:** `ZK_SHIELD=1` · RSS never sold · no temporary HOT throne · no paper games

---

## Result

| Field | Value |
|--|--|
| **Status** | **WALKED** |
| Elephant | [`0x03bdf75d11237c0560f48527f360640d9c7ddcaa`](https://basescan.org/address/0x03bdf75d11237c0560f48527f360640d9c7ddcaa) |
| Owner | HOT `0x6708…a7d1` |
| Deploy tx | [`0x09255582…abf5`](https://basescan.org/tx/0x092555822f08ba5d42f214c773e6c89b047ba228c5e5a195207dcc8b97a8abf5) |
| Oracle → Elephant | [`0xe71a86cf…26c9`](https://basescan.org/tx/0xe71a86cfcc13cb775f67d7390ea7f7e7b240cc06c4edf942199543a9338b26c9) |
| `fire()` | [`0x2c8a9255…4e59`](https://basescan.org/tx/0x2c8a9255602e2848236eb13a9bd2916bfa35b3a5c6c1c5e92b2ab6e275894e59) |

## Positions (live post-fire)

| Book | Address | borrowShares | collateral RSS |
|--|--|--:|--:|
| Legacy Gate `0x76fa…` | SOV `0x1293…` | **0** | dust `68931805760` wei (~6.9e-8 RSS) |
| **Elephant** | SOV `0x1293…` | **`3005404032523000000`** | **`222521940922637943194240`** (~222,521.94 RSS) |
| Elephant | PAR `0x1bfd…` | 0 | 0 |

| Oracle | Value |
|--|--|
| owner | **HOT** (returned) |
| price | **`5e28`** ($50,000) |

## What walked

1. Morpho flash ~$3.010M USDC  
2. Live-calibrated temp oracle (Morpho LIF band) → full `repaidShares` self-del of Gate  
3. Seize ~222,521.94 RSS (no bad-debt socialize)  
4. Restore oracle $50k  
5. Reseat RSS + ~$3.005M debt on **Elephant** (HOT-owned) using freed SOV idle  
6. Repay flash · return oracle to HOT  

## Why SOV reseat (not PAR yet)

| Blocker | Fact |
|--|--|
| PAR `0x1bfd…` idle | **$0** — cannot borrow to repay flash |
| SOV LP holders | `CrownKingsCombinedFire` `0x37C9…` (~$2M) + `CrownKingsFire` `0x16a3…` (~$1M) |
| LP withdraw | **none** — fire contracts have no Morpho `withdraw` / peel |
| yRSS on SOV | **0 shares** — PA cannot reallocate SOV→PAR |

PAR seat remains the next hop once Kingdom SOV LP is peelable or external USDC seeds `0x1bfd…`.

## Meaning

RSS is **off the jammed Safe Gate** and under a HOT-owned Elephant Morpho position on the sovereign 77% rail. King can operate the book without Safe nonce. Dust on Gate is economically zero; debt on Gate is **cleared**.

```
FIRE_ELITE_ELEPHANT=1
ELEPHANT=0x03bdf75d11237c0560f48527f360640d9c7ddcaa
TX_DEPLOY=0x092555822f08ba5d42f214c773e6c89b047ba228c5e5a195207dcc8b97a8abf5
TX_ORACLE=0xe71a86cfcc13cb775f67d7390ea7f7e7b240cc06c4edf942199543a9338b26c9
TX_FIRE=0x2c8a9255602e2848236eb13a9bd2916bfa35b3a5c6c1c5e92b2ab6e275894e59
GATE_DEBT=0
ELEPHANT_SOV_COLL~=222521.94
ELEPHANT_SOV_DEBT~=3005404
ORACLE_OWNER=HOT
ORACLE_PRICE=5e28
PAR=DEFERRED_NO_IDLE_NO_LP_PEEL
NEXT=PEEL_KINGSFIRE_LP_OR_SEED_PAR
```
