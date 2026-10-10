# FIRE — Path B max-free migrate (gap STRUCK)

**Mode:** FIRE · Base · block **~52196890**  
**Law:** Path A removed · **$4.4M gap STRUCK** · flash + King yRSS only

---

## Result

| Book | Collateral RSS | Borrow |
|--|--:|--:|
| **Sovereign** `0x1293…2f7b` (oracle **$50k**) | **222,521.94** | **0** |
| Legacy `0x41c0…7d88` (oracle $1200) | **29,478.06** | residual shares (healthy) |
| **Pct on King oracle** | **88.30%** | — |

---

## Txs

| Step | Hash |
|--|--|
| Migrator create | [`0x7922e9bc…39af`](https://basescan.org/tx/0x7922e9bc587d4cb067efe8a3dd09f2224a47c6d3de85ef3243daa529f95439af) → `0xb2d179186053e1935F40bB7E3bbb4f72d7Cd3f44` |
| yRSS approve | [`0x3b6b2619…ea17`](https://basescan.org/tx/0x3b6b26191447e7622a4523281174611f72e52e2f1326d5c6030149d4a088ea17) |
| Morpho setAuthorization | [`0x9af518f5…9383`](https://basescan.org/tx/0x9af518f5ecdb349d838d5f2ccffcd3689f31188eaea576816d7edff80fb79383) |
| **migrate()** | [`0x9a29bde5…ba77`](https://basescan.org/tx/0x9a29bde5246ff404ab4f9462845fc69fd22b1bfb46738ab5dfef6dce0209ba77) |

CrownOracle (prior): `0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d` · `price()=$50,000`

---

## Struck

| Item | Status |
|--|--|
| $4.4M yRSS gap | **STRUCK** — not used, not a gate |
| Path A treasury | **REMOVED** |
| King USDC inject | **0** |

```
FIRE_PATH_B=1
SOVEREIGN_RSS=222521.94
LEGACY_RSS_RESIDUAL=29478.06
ORACLE_USD=50000
GAP_4_4M=STRUCK
```
