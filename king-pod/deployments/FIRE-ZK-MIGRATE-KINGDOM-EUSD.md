# FIRE — Bring Kingdom eUSD under ZK / Safe

**Status:** FIRST WAVE LIVE · HOT gUSD cleared · gas pause on remaining 7M desk inventory  
**Rail:** `0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3`  
**Safe onBehalf:** `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0`

## Migrated this fire (onBehalf = Safe)

| Source | Amount eUSD | Notes |
|--|--:|--|
| HOT gUSD unwrap `0x319A…` | **2,033,908,663.50** | 100M + 500M + 1B + 433.9M remainder |
| `0xAb216237…dc3B2` sweep | **100,000,000** | HOT-owned |
| `0x9199e509…8060b` sweep3 | **100,000.00** | HOT-owned |
| `0xF7337A26…F987` sweep | **1.00** | multi-PSM dust |
| **Total new on rail** | **~2,134,008,664.50** | |

**Rail `totalSupplied`:** `1,925,450,360` → **`4,059,459,024`**

### Anchor txs (Base)

| Step | Tx |
|--|--|
| First 100M unwrap | `0x9f041f7d919f3fb1051c0c1ab5a81309508fd09f2f383c0f5b2333547d167ed8` |
| First 100M zkSupply | `0x650fc4288e3e75f07fb9ee42a375f899d26681388cce8d0ba433c1fe833cd6be` |
| Later chunks | `broadcast/FireZkMigrateGusdChunk.s.sol/8453/` · `FireZkMigrateSweepChunk` · `FireZkMigrateSweep3Chunk` |

## V3 executor stub

`migrateFirst100M()` on `0x184e4…` still **reverts `AwaitHandoff`**. Real path used: unwrap/sweep → `CrownZkMorphoRail.zkSupply`.

## Remaining Kingdom-controlled (not yet migrated)

| Address | eUSD | Blocker |
|--|--:|--|
| `0x4C021c77…720Ab` | 5,000,000 | extract selector not confirmed |
| `0xC28E7faA…9F6B` | 2,000,000 | linked to 4C; pull selector not confirmed |
| `0x97bd6846…bB68` (EXIT) | 3.99 | no working rescue yet |
| HOT ETH | ~0.0000017 | **need tip** before next wave |

## External (do not migrate)

| Address | eUSD | Class |
|--|--:|--|
| `0x8C009d96…FE7` | 5,000,000,000 | Stable AMM gUSD/eUSD — public float |
| gUSD reserve `0x319A…` | ~5,030,000,000 | backs AMM gUSD supply (HOT gUSD = 0) |
| Morpho `0xBBBB…` | ~1.81B+ | protocol vault (includes Safe seat) |

## Next (after ≥0.001 ETH on HOT)

1. Crack 4C/C28 release (desk pair — 4C view points at C28).  
2. Sweep EXIT dust.  
3. Leave AMM 5B as marked public float unless King orders LP unwind.
