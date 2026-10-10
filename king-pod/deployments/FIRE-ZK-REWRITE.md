# FIRE — ZK Rewrite (on-chain backbone)

**Mode:** FIRE · Base · **LIVE**  
**Law:** WalletGate `isProven` + `bordersSecure` **inside contracts** — not script env theater

---

## Done

### 1) HOT Morpho spoil rewritten through ZK rail

| Field | Value |
|--|--|
| CrownZkMorphoRail | [`0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3`](https://basescan.org/address/0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3) |
| Owner | Safe |
| HOT Morpho shares | **0** |
| Rail `totalSupplied` | **~301M eUSD** (HOT leg via `zkSupply`) |
| Deploy | [`0x80d6cfc6…737c`](https://basescan.org/tx/0x80d6cfc67a1feae24399a01ff78f5a9bb8cd4812b3fe6a6796f48f9320db737c) |

`zkSupply` / `zkWithdraw` revert unless `isProven(msg.sender)` · `isProven(Safe)` · `bordersSecure`.

### 2) ZK Falcon stack (replaces unshielded Falcon)

| Contract | Address |
|--|--|
| CrownHotOracle50kZk | `0x869F9b09E8129bAa9d2B0eC151863256F102C15F` |
| CrownKRT | `0xdFF6ea9b351e5BBc760a6Db23fc354BB6fC53cd8` |
| CrownGusd | `0xAFA2D89C48DAf93cEEe80B1F37D4A7BAA12a30a5` |
| CrownHarvesterZk | `0x96eB2843A583002490620C755e3bcE8f9ACDafe0` |
| Crown369 | `0x9E0a2b0Bd76180e005d8494071D9D093a5CccEdF` |

All owned by **Safe**. Oracle price writes + harvester seeds require on-chain ZK.

Legacy unshielded Falcon (`0xF98b…` oracle etc.) is obsolete — do not use.

### 3) Borders restored for fire

- `navThreshold` aligned to live yRSS NAV (~30e12)
- `bordersSecure=true` · WalletGate HOT+Safe proven

---

## Awaiting King (Safe 2-of-3)

Landing ~1.32B entered Morpho **before** the ZK rail. Safe must withdraw → `zkSupply` on `0xa787…`.

→ `HANDOFF-SAFE-ZK-REWRITE.md`

```
HOT_ZK_REWRITE=DONE
ZK_FALCON=DONE
SAFE_LEG_ZK_REWRITE=AWAIT_2OF3
ZK_RAIL=0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3
```
