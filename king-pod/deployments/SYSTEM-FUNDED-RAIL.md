# System-funded rail — LIVE

External USDC → FHE vault → swap sleeve → WETH Morpho/V2 → fee shares to hot.

## Live addresses
| Piece | Address |
|--|--|
| Vault V2 (WETH) | `0x35a00F116536c13A63273513990E4E496a15Ddb2` |
| MetaMorpho yELEPAN-WETH | `0xfdD5a1d4823411809D6ac735991B3A015E5AaAb5` |
| **CrownFhePrivateVaultV2** | `0x761C50d494F9BC188cbAaF55dbE3d7A90Fa7Bb0B` |
| **CrownUsdcWethSleeve** | `0xc5084FAB16F72140507C6c079f9157184c8eFBBC` |
| CrownZkElepanCredit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| Elepan ZK gate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| Old FHE scaffold | `0x79A2B9211eAD823203345f8613a07f3681e38dD9` (superseded by v2) |

## Vault V2 fees (FIXED)
| Fee | Value | Recipient |
|--|--|--|
| Performance | **10%** (`0.1e18`) | hot |
| Management | **1%/yr** (`317097919` per-sec = `0.01e18/365d`) | hot |
| Gates | all `0x0` (permissionless) | — |

**API note:** V2 management fee is **per-second**, not annual WAD. Annual 1% → `0.01e18 / 365 days`.  
Fee shares mint to recipients on `accrueInterest` / deposit / withdraw.

## Sleeve path
1. Lender `deposit(usdc)` on FHE v2  
2. Proven King `allocate(usdcIn, minWethOut, morphoBps)` → sleeve `route`  
3. Uni V3 USDC→WETH → deposit MetaMorpho and/or V2  
4. Yield → V2/MM fee shares → hot redeems  

## Next (external capital)
Publish FHE v2 + ZK credit deposit addresses. No hot USDC required — external deposits fund the loop.
