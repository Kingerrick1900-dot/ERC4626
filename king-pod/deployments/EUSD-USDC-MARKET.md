# Kingdom eUSD / USDC Morpho market — frozen $1 oracle

**LIVE Base.** Companion to the RSS/$1200 market (Morpho markets cannot be patched — this is a **new** market).

| | |
|--|--|
| Market ID | `0x5acc6ed4af3764d5081347db21940c8d25d90f186b263d04e8fd8cd267e45184` |
| Oracle | `0xACCeCEDE28fC46481299b9306a7D414698dE8584` |
| Price | **$1** / eUSD (`1e24` Morpho scale) — **frozen** |
| Collateral | Kingdom eUSD `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** |

## Status

Created tooling. **Empty** (no USDC supply yet).

You can post eUSD as collateral only after (or when) USDC is supplied to this market. Collateral alone does not mint borrowable USDC.
