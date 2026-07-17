# Unit D — Curator listing packet (LIVE)

**Status:** Ready to submit. PoD book live. Public Allocator armed on King yRSS.

## Ask
Enable Public Allocator **flow caps** so USDC can reallocate **into** King RSS/USDC market, then Kingdom borrows to KingVault.

## Market (Base 8453)
| Field | Value |
|--|--|
| Market ID | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | MorphoFixedOracle `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` — **$1 fixed** (King-owned) |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | 77% |

## Live Proof-of-Demand (on-chain now)
| Metric | Value |
|--|--|
| Supply / Borrow | **~$9.25M / $9.25M** |
| Utilization | **100%** |
| RSS collateral | **~18.5M** |
| Health factor | **~1.54** |
| Scale tx | `0x00d9ce8219dafc0697b9cd487c9327660a405ef498894ab551819f4d8bb6dba0` |

High util = max IRM borrow rate = yield magnet for PA vaults.

## King vault (already PA-wired)
| Field | Value |
|--|--|
| yRSS-USDC | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Owner / curator / allocator | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Performance fee | 10% → KingVault |
| PA | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` (allocator = true, fee = 0) |
| RSS flow caps | maxIn / maxOut **$14M** |
| Multi-market | cbBTC + WETH USDC books armed for PA maxOut → RSS maxIn |

## Requested from target curators
Start: **`maxIn` = $700,000 USDC** on RSS market (scale after proof).  
`maxOut` per vault policy.  
Enable market via submitCap / acceptCap.  
Ensure Public Allocator is vault allocator.

### Target vaults
1. Gauntlet USDC Prime — `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` (~$426M)
2. Steakhouse Prime USDC — `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` (~$230M)
3. Steakhouse USDC — `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` (~$192M)
4. Steakhouse High Yield USDC v1.1 — `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F`

## On-chain steps (curator)
1. `submitCap` / `acceptCap` for RSS/USDC market  
2. `PublicAllocator.setFlowCaps(vault, [{id: MARKET_ID, maxIn: 700_000e6, maxOut: …}])`  
3. Confirm PA is allocator  

## Kingdom fire after maxIn > 0
Atomic spoil path (`CrownSpoilFire` / `FireReallocateBorrow`):
1. `PA.reallocateTo` → USDC into RSS market  
2. `Morpho.borrow` on King position → **KingVault** `0xA1aFcb46a64C9173519180458C1cF302179c832a`  
3. Keep RSS collateral + debt (hold, not elite-close)

Borrow headroom at $1 / 77% LLTV / HF~1.54: **~$5M** available once idle USDC appears.

## Contact
Morpho curator Discord / Gauntlet + Steakhouse listing forms.  
Packet by Kingdom Scribe for **King Errick**.
