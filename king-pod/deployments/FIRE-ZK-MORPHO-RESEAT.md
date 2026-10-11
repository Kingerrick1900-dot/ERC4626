# FIRE — Morpho → ZK rail reseat (Safe book)

**Status:** LIVE · COMPLETE  
**Mode:** HOT operator (Morpho `isAuthorized(Safe, HOT)=true`) · `ZK_SHIELD=1`

## Result

| Field | Value |
|--|--|
| Withdrawn + zkSupplied | **3,765,459,033.721143226** eUSD |
| Rail `totalSupplied` before | `4,066,459,028.731982756` |
| Rail `totalSupplied` after | **`7,831,918,062.453125768`** |
| Capacity ceiling | 100T eUSD · **OK** |
| Safe Morpho shares | restored (full book under rail path) |
| HOT eUSD | **0** |

> Live Morpho book was the full Safe seat (~3.765B), not the older 1.81B scan figure (pre–gUSD wave). Full shares withdrawn — no partial.

## Txs (Base)

| Step | Tx |
|--|--|
| Morpho `withdraw` (all Safe shares → HOT) | [`0x0aa6703011214dd9b924153e223905909d788fc2c61a39896797c2f8313299fc`](https://basescan.org/tx/0x0aa6703011214dd9b924153e223905909d788fc2c61a39896797c2f8313299fc) |
| eUSD `approve` rail | [`0xc0dc9ccad25728eb5413e563737469885da499609bc2e00bf3d31ca26f557396`](https://basescan.org/tx/0xc0dc9ccad25728eb5413e563737469885da499609bc2e00bf3d31ca26f557396) |
| `zkSupply` onBehalf Safe | [`0xfec61e728edfe316311dc162e5c06d588512a98faf6d1d45d4641457f11f0107`](https://basescan.org/tx/0xfec61e728edfe316311dc162e5c06d588512a98faf6d1d45d4641457f11f0107) |

## Path notes

- `CrownZkMigrationExecutorV3_100T.migrateFirst100M` still **reverts `AwaitHandoff`** — not used.
- Live path: `script/FireZkMorphoReseatSafe.s.sol` (same doctrine as `FireZkRewriteSafeViaHot`).
- Market: eUSD/RSS `0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599` on Morpho `0xBBBB…`.
- AMM 5B public float untouched.

```
FIRE_ZK_MORPHO_RESEAT=DONE
RAIL_TOTAL=7831918062453125767955055514
CAP_OK=1
```
