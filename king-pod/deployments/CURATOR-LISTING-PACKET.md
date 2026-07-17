# Unit D — Curator listing packet (FINISHED / SUBMIT NOW)

**Status:** COMPLETE — broadcast of the engineered position. Oracle $1. PoD ~$9.25M @ 100% util. King PA maxIn $700k. Submit so their PA can answer the position with USDC.

## 5-step Kingdom rail
1. Finish curator package ← **this doc**
2. Activate Public Allocator ← **DONE on King yRSS**
3. Pull USDC into RSS market ← blocked on foreign vaults until they set `maxIn`; King yRSS path live
4. Borrow against PoD book
5. USDC lands in KingVault `0xA1aF…832a`

---

## Ask (one line)
Enable RSS/USDC on your MetaMorpho vault with Public Allocator **`maxIn = $700,000` USDC** (scale after proof) so USDC can `reallocateTo` into the market; Kingdom borrows to KingVault against live RSS collateral.

## Market (Base 8453)
| Field | Value |
|--|--|
| Market ID | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | MorphoFixedOracle `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` — **$1 fixed** |
| IRM | AdaptiveCurveIRM `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** (`770000000000000000`) |

## Live Proof-of-Demand (on-chain)
| Metric | Value |
|--|--|
| Supply / Borrow | **~$9.25M / $9.25M** |
| Utilization | **~100%** (max IRM borrow rate = yield magnet) |
| RSS collateral posted | **~18.5M** |
| Health factor | **~1.54** |
| Borrow headroom @ 77% LLTV | **~$5M** once idle USDC appears |
| Scale tx | `0x00d9ce8219dafc0697b9cd487c9327660a405ef498894ab551819f4d8bb6dba0` |

## King yRSS (reference PA wiring — already live)
| Field | Value |
|--|--|
| Vault | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Owner / curator | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Fee | 10% → KingVault `0xA1aFcb46a64C9173519180458C1cF302179c832a` |
| Public Allocator | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` (**isAllocator = true**, fee = 0) |
| Caps | RSS + cbBTC/USDC + WETH/USDC enabled, supply cap **$14M** each |
| PA flow caps (formalized) | **maxIn / maxOut = $700,000** (`700_000e6`) on RSS + cbBTC + WETH |
| PA set tx | `0x90caf4944f6471e98d28f4529c43b5be08943eb5a437b1d5c2e48c19121c1891` |

## Formal PA parameters (submit these exact numbers)
| Param | Value |
|--|--|
| `maxIn` (RSS market) | **`700_000e6`** = **$700,000 USDC** |
| `maxOut` (source USDC books) | **≥ `700_000e6`** |
| Public Allocator | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| Market ID | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| Pull size | **$700k** from another market (not dust) → borrow → KingVault |

## Target vaults — live gate status (why this packet matters)
| Vault | Address | ~TVL USDC | RSS enabled | PA allocator | RSS maxIn |
|--|--|--|--|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` | ~$427M | **NO** | YES | **0** |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` | ~$230M | **NO** | YES | **0** |
| Steakhouse USDC | `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` | ~$191M | **NO** | YES | **0** |
| Steakhouse High Yield USDC | `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F` | ~$2.7M | **NO** | YES | **0** |

## Curator on-chain checklist (copy/paste)
1. `submitCap(RSS_MARKET_PARAMS, supplyCap)` then `acceptCap` (timelock per vault)
2. `PublicAllocator.setFlowCaps(vault, [{id: MARKET_ID, maxIn: 700_000e6, maxOut: per policy}])`
3. Confirm `vault.isAllocator(PA) == true` (already true on targets above)
4. Ping Kingdom — we fire `reallocateTo` → `borrow` → KingVault same path as `CrownSpoilFire`

## Kingdom fire after maxIn > 0
```
PA.reallocateTo(vault, withdrawalsFromIdleMarkets, RSS_MARKET)
Morpho.borrow(RSS_MARKET, assets, 0, KING, KING_VAULT)
```
Contracts ready: `CrownSpoilFire` `0xcFF60f3B071c09C17853bA715ceDc0Fc2e6645Fa` (Morpho-authorized).

## Submit channels
- Morpho Discord — curator / listing channels  
- Gauntlet vault listing / risk intake  
- Steakhouse listing forms / Morpho forum  

**Packet owner:** Kingdom Scribe for **King Errick**  
**Receiver / KingVault:** `0xA1aFcb46a64C9173519180458C1cF302179c832a`
