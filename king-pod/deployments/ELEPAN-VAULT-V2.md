# Elepan Vault V2 — LIVE (adapter path)

WETH Vault V2 with MorphoMarketV1AdapterV2 → Elepan/WETH market.  
(MetaMorpho `yELEPAN-WETH` `0xfdD5…` remains the MM vault; this is the adapter/registry stack.)

## Addresses
| Piece | Value |
|--|--|
| VaultV2 | `0x35a00F116536c13A63273513990E4E496a15Ddb2` |
| MorphoMarketV1AdapterV2 | `0x384A596C90D64004d0Fcb3d5cB79CE62f9C4F585` |
| Adapter registry | `0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a` (abdicated) |
| Asset | WETH |
| Market | Elepan/WETH `0xac7c17fa…ed44` |
| Curator / owner | hot `0x6708…a7d1` |
| Allocators | hot + PublicAllocator `0xA090…0467` |
| forceDeallocate penalty | 1% |
| Dead shares (`0xdead`) | live |

## Caps (Vault V2 pattern — not MetaMorpho submitCap)
```text
submit(increaseAbsoluteCap(idData, type(uint128).max))
increaseAbsoluteCap(idData, type(uint128).max)   // exec after timelock=0
submit(increaseRelativeCap(idData, 1e18))
increaseRelativeCap(idData, 1e18)
```
**Bug fixed:** `uint256.max` reverts — caps are `uint128`.

## Create txs
| Step | Tx |
|--|--|
| createVaultV2 | `0xcebfc9d6…d2d0bd` |
| createAdapter | `0x94bd12c8…fedfd2` |
| dead deposit | `0xacf45571…56bc90` |

## FHE rail (separate)
`CrownFhePrivateVault` `0x79A2B9211eAD823203345f8613a07f3681e38dD9` — ZK-gated institutional USDC; Zama ciphertext hook ready.
