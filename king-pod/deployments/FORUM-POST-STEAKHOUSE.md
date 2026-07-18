# [Steakhouse High Yield USDC — Base] Market listing request: RSS/USDC

**Category:** Vaults → SteakHouse Financial  
**Post URL target:** https://forum.morpho.org/c/vaults/steakhouse-financial/18  
**Submitter:** Kingdom (King Errick) — Morpho Blue borrower / market creator on Base

---

## Summary

Request enablement of the live **RSS/USDC** Morpho Blue market on **Steakhouse High Yield USDC** (Base) with Public Allocator `maxIn = $700,000` USDC (initial). Prime vaults are **out of scope** until secondary-market RSS depth is seeded; HY is the correct risk bucket.

## Market (Base 8453)

| Field | Value |
|--|--|
| Market ID | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | Morpho FixedOracle `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` — **$1 fixed**, **owner = `0x…dEaD`** (immutable) |
| Oracle lock tx | `0x7b35b2769fb3a05d6962de25e8ab6cf07e7da0d90d64d237eddd8d317bde4726` |
| IRM | AdaptiveCurveIRM `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | 77% |

## Proof-of-demand (on-chain)

- Supply ≈ borrow **~$9.25M** at **~100% utilization**
- ~**18.5M RSS** collateral posted; HF ~**1.54**
- Scale tx: `0x00d9ce8219dafc0697b9cd487c9327660a405ef498894ab551819f4d8bb6dba0`

Idle USDC allocated here earns the AdaptiveCurve max borrow rate immediately.

## Risk parameters requested

| Param | Ask |
|--|--|
| Vault | Steakhouse High Yield USDC `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F` |
| Supply cap | **$700,000** USDC (scale after review) |
| PA | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` (already allocator on vault) |
| `maxIn` | **`700_000e6`** |
| `maxOut` | per Steakhouse policy (≥ ask size on source books) |

On-chain steps: `submitCap` → timelock → `acceptCap` → `PublicAllocator.setFlowCaps`.

## Liquidity depth (transparent)

As of 2026-07-18: **no** Uni V2/V3 or Aerodrome RSS/USDC or RSS/WETH pools indexed. We are seeding secondary depth in parallel (UniV3 RSS/USDC) and will update this thread with pool address + reserve USD when live. Initial cap at $700k is sized for that reality.

## Oracle stance

Morpho’s native FixedOracle. Price admin burned to `dEaD` — `setPrice` reverts `OWNER`. Same market id retained (no migration).

## Contact / receiver

Borrowed USDC receiver (Kingdom treasury trough): KingVault `0xA1aFcb46a64C9173519180458C1cF302179c832a`.

Happy to jump on risk review with any additional data Steakhouse needs.
