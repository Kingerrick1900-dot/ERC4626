# BIND — Fix 3 reds (live)

**Status:** DEPLOYED · Base  
**Script:** `FireBindFix3Reds.s.sol`

## Active registry (fee→Safe · events · no AwaitHandoff)

| Piece | Address |
|--|--|
| CrownZkMorphoRail | `0xf0f2af7e5E68819342fD708eB4D606b79067A529` |
| Executor V3 | `0xD242E57CAB02D62ba238812479D136Fcb1a2EDbB` |
| Nigeria desk | `0x6bb2e8A726092F73648914De278401B5db36e079` |
| China harvester | `0x1472dF7FA5d8e9F2Bd14aE761d875496DBE0CF60` |
| feeSink / china.hot | Safe `0x23590FEb…eac0` |

## Retired

| Piece | Address | Why |
|--|--|--|
| Old rail | `0xa787…` | no CapacityCheck / WalletMigrated |
| Old V3 stub | `0x184e4…` | AwaitHandoff |
| Old Nigeria | `0x4987…` | feeSink=HOT |
| Old China | `0x09BB…` | hot=HOT |

Broadcast: `broadcast/FireBindFix3Reds.s.sol/8453/run-latest.json`
