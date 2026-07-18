# [Gauntlet — Base] Market listing request: RSS/USDC (Core / non-Prime)

**Category:** Vaults → Gauntlet  
**Post URL target:** https://forum.morpho.org/c/vaults/gauntlet/19  
**Submitter:** Kingdom (King Errick) — Morpho Blue market on Base

---

## Summary

Request Gauntlet enable the live **RSS/USDC** Morpho Blue market for allocation from a **non-Prime** Base USDC vault (Core / Frontier / equivalent risk bucket — **not** USDC Prime until RSS secondary depth is live), with Public Allocator `maxIn = $700,000` USDC initial.

Gauntlet USDC Prime on Base (`0xeE8F…4b61`) is blue-chip-mandated; we are not asking Prime to break mandate. We are asking the correct risk sleeve + PA flow so 100%-util PoD can clear.

## Market (Base 8453)

| Field | Value |
|--|--|
| Market ID | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | Morpho FixedOracle `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` — **$1**, owner **`0x…dEaD`** |
| Oracle lock tx | `0x7b35b2769fb3a05d6962de25e8ab6cf07e7da0d90d64d237eddd8d317bde4726` |
| IRM | AdaptiveCurveIRM `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | 77% |

## PoD

~$9.25M supply≈borrow @ ~100% util; ~18.5M RSS collateral; HF ~1.54.  
Scale: `0x00d9ce8219dafc0697b9cd487c9327660a405ef498894ab551819f4d8bb6dba0`

## Risk ask

| Param | Value |
|--|--|
| Initial supply cap | **$700,000** USDC |
| PA | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| `maxIn` | **`700_000e6`** |

## Liquidity depth

No indexed DEX pools for RSS/USDC or RSS/WETH as of packet date. Depth seeding is an explicit parallel workstream; cap sized accordingly. We will reply in-thread with pool + `reserve_in_usd` when live.

## Oracle

Morpho-native FixedOracle; admin burned; price immutable at $1; market id unchanged.

## Receiver

KingVault `0xA1aFcb46a64C9173519180458C1cF302179c832a`

Open to Gauntlet risk questionnaire / VaultBook criteria mapping.
