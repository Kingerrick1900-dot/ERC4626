# KING SAVE SHEET — Base (8453)
**Live snapshot:** 2026-07-18 · Chain: Base

---

## 1) Morpho Blue markets (THE IDs)

### RSS/USDC — primary PoD book
```
MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
```
| Param | Value |
|--|--|
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | FixedOracle `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** (`770000000000000000`) |
| Supply / Borrow | **~$9.25M / $9.25M** (100% util) |
| Hot collateral posted | **~18.5M RSS** |
| Hot borrow | **~$9.25M** USDC |
| HF (approx) | **~1.54** |

### BRETT/USDC — oracle moat (Kingdom-created)
```
MARKET_ID = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16
```
| Param | Value |
|--|--|
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | BRETT `0x532f27101965dd16442E59d40670FaF5eBB142E4` |
| Oracle | UniV3 TWAP `0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **62.5%** (`625000000000000000`) |
| Create market tx | `0x694f9308069c1d505254906e51068096a16df576937e85c77a753075a88479a4` |
| Oracle deploy tx | `0x1bdfb4f9a794bb48fbbd010f2450e70d8d4875d32d22175eac8f4965ceb7fae5` |

### Other markets on yRSS supply queue
| Slot | Market ID | Role |
|--|--|--|
| 0 | `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836` | cbBTC/USDC (idle source) |
| 1 | `0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda` | WETH/USDC (idle source) |
| 2 | `0x40ac09f3…b794` | **RSS** |
| 3 | `0xf6f43f16…8c16` | **BRETT** |

---

## 2) Kingdom vaults & wallets

| Name | Address | Notes |
|--|--|--|
| **Hot / Owner** | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | Signs, curator, Morpho position |
| **KingVault** (USDC trough) | `0xA1aFcb46a64C9173519180458C1cF302179c832a` | **EOA** receive — not ERC4626; holds ~6.97 USDC |
| **yRSS** MetaMorpho | `0xF80C0529bD94C773844E459853CD91B9263dD525` | `King RSS USDC Vault` / `yRSS-USDC` |
| Loop wallet | `0x8d3cfbFc6A276f118579517E4d166e94C66F8585` | Dust loop / ops |
| CrownSpoilFire | `0xcFF60f3B071c09C17853bA715ceDc0Fc2e6645Fa` | Armed fire contract |

### yRSS curator numbers
| Field | Value |
|--|--|
| Owner / Curator | Hot `0x6708…a7d1` |
| Guardian | `0x0` (none) |
| Fee | **10%** (`1e17`) |
| Fee recipient | KingVault `0xA1aF…832a` |
| Timelock | **0** |
| TVL | ~**$545.87** USDC |
| PA isAllocator | **true** |
| PA admin | Hot |

### yRSS caps / PA flow (formal ask size **$700k**)
| Market | Enabled | Supply cap | maxIn | maxOut |
|--|--|--|--|--|
| RSS | YES | **$14,000,000** | **~$699.5k** | **~$700.5k** |
| BRETT | YES | **$2,000,000** | **$700,000** | **$700,000** |

```
PA_ASK_USDC     = 700_000e6   // 700000000000
RSS_CAP_USDC    = 14_000_000e6
BRETT_CAP_USDC  = 2_000_000e6
```

---

## 3) Oracles

| Oracle | Address | Price (Morpho scale) | Owner |
|--|--|--|--|
| RSS FixedOracle | `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` | `1e24` = **$1** | **`0x…dEaD`** (burned) |
| BRETT UniV3 TWAP | `0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619` | `~5.031e21` ≈ **$0.00503** | n/a (no admin) |
| BRETT pool | UniV3 BRETT/USDC 1% `0xBF0A0C12E7C0610002F6Aa6E609755EDe42D6A4d` | TWAP 1800s | — |

Oracle lock tx (RSS): `0x7b35b2769fb3a05d6962de25e8ab6cf07e7da0d90d64d237eddd8d317bde4726`

---

## 4) Protocol constants (Base)

| Contract | Address |
|--|--|
| Morpho Blue | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| Public Allocator | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| AdaptiveCurveIRM | `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| MetaMorpho Factory | `0xFf62A7c278C62eD665133147129245053Bbf5918` |
| Bundler3 (unused this phase) | `0x6BFd8137e702540E7A42B74178A4a49Ba43920C4` |
| Chainlink Oracle Factory | `0x2DC205F24BCb6B311E5cdf0745B0741648Aebd3d` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| WETH | `0x4200000000000000000000000000000000000006` |
| cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` |

---

## 5) Foreign vault targets (still maxIn=0 on RSS)

| Vault | Address |
|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` |
| Steakhouse USDC | `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` |
| Steakhouse HY USDC | `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F` |

---

## 6) One-block copy (phone notes)

```
CHAIN=8453 Base
RSS_MARKET=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
BRETT_MARKET=0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16
YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525
KING_VAULT=0xA1aFcb46a64C9173519180458C1cF302179c832a
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
PA=0xA090dD1a701408Df1d4d0B85b716c87565f90467
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
RSS_ORACLE=0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e
BRETT=0x532f27101965dd16442E59d40670FaF5eBB142E4
BRETT_ORACLE=0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
IRM=0x46415998764C29aB2a25CbeA6254146D50D22687
PA_ASK=700000e6
RSS_LLTV=77%
BRETT_LLTV=62.5%
```
