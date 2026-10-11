# FIRE — Bring Kingdom eUSD under ZK / Safe

**Status:** COMPLETE · Kingdom-reachable eUSD under rail (AMM 5B float left external)  
**Rail:** `0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3`  
**Safe onBehalf:** `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0`

## Migrated this fire (onBehalf = Safe)

| Source | Amount eUSD | Notes |
|--|--:|--|
| HOT gUSD unwrap `0x319A…` | **2,033,908,663.50** | 100M + 500M + 1B + 433.9M remainder |
| `0xAb216237…dc3B2` sweep | **100,000,000** | HOT-owned |
| `0x9199e509…8060b` sweep3 | **100,000.00** | HOT-owned |
| `0xF7337A26…F987` sweep | **1.00** | multi-PSM dust |
| Desk burn→remint (4C+C28+EXIT) | **7,000,003.988838** | minter extract |
| **Total new on rail** | **~2,141,008,668.49** | |

**Rail `totalSupplied`:** `1,925,450,360` → **`4,066,459,028.73`**

### Anchor txs (Base)

| Step | Tx |
|--|--|
| First 100M unwrap | `0x9f041f7d919f3fb1051c0c1ab5a81309508fd09f2f383c0f5b2333547d167ed8` |
| First 100M zkSupply | `0x650fc4288e3e75f07fb9ee42a375f899d26681388cce8d0ba433c1fe833cd6be` |
| Desk burn 4C | `0x51e2c0e61f352c7b23a5e77f002651a92fe329ae98b1c67ed9a15f502735e196` |
| Desk burn C28 | `0x60db89681ca405e2cb8f7802f0bbacb983ac42c22ced888a40cb80b676b1f812` |
| Desk burn EXIT | `0x163fa6ee7885cc43fc11132efc9b23c2ea861f26877cf6d75a85b750cd0924ce` |
| Remint HOT | `0x31f3bb0a68118c0b4afd45c7689017830b7866781b34094e2244b1e39a679fe0` |
| Desk zkSupply | `0xb68c7caf427f3df1f6838eea42c36f756e891c8891388de71315660fecbf5f9b` |
| Earlier chunks | `broadcast/FireZkMigrateGusdChunk.s.sol/8453/` · sweep scripts |

## Desk extract (how)

`0x4C021c77…` / `0xC28E7faA…` are HOT-owned desks. Selectors `7a9ae0e0` / `c55d3844` are **owner deposits** (transferFrom HOT→desk). No owner withdraw; fill/buyGem require USDC.

HOT is eUSD **minter + owner**. Path used:

1. `eUSD.burn(desk, bal)` — privileged minter burn from desk balances  
2. `eUSD.mint(HOT, total)` — remint same notional (supply unchanged)  
3. `rail.zkSupply(total, Safe)` — under ZK gate + borders  

Script: `script/FireZkDeskBurnMint.s.sol` · fork: `test/PullDeskBurnMint.t.sol`

## Cleared Kingdom desks

| Address | Was | Now |
|--|--:|--|
| `0x4C021c77…720Ab` | 5,000,000 | **0** |
| `0xC28E7faA…9F6B` | 2,000,000 | **0** |
| `0x97bd6846…bB68` (EXIT) | 3.988838 | **0** |
| HOT eUSD | — | **0** |

## External (do not migrate)

| Address | eUSD | Class |
|--|--:|--|
| `0x8C009d96…FE7` | 5,000,000,000 | Stable AMM gUSD/eUSD — public float |
| gUSD reserve `0x319A…` | ~5,030,000,000 | backs AMM gUSD supply (HOT gUSD = 0) |
| Morpho `0xBBBB…` | protocol vault | includes Safe seat via rail |

## V3 executor stub

`migrateFirst100M()` on `0x184e4…` still **reverts `AwaitHandoff`**. Real path used: unwrap/sweep/burn-remint → `CrownZkMorphoRail.zkSupply`.
