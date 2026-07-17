# Unit D — Curator listing packet (RSS/USDC Morpho Blue on Base)

## Ask
Enable Public Allocator **flow caps** so USDC can reallocate **into** King RSS/USDC market.

## Market
- Chain: Base (8453)
- Market ID: `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`
- Loan: USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Collateral: RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337`
- Oracle: MorphoFixedOracle `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` (King-owned; target $1)
- IRM: `0x46415998764C29aB2a25CbeA6254146D50D22687`
- LLTV: 77%

## King vault (already live)
- yRSS-USDC MetaMorpho: `0xF80C0529bD94C773844E459853CD91B9263dD525`
- Curator / owner / allocator: `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`
- Performance fee: 10%

## Requested caps (start)
- `maxIn` on RSS market: **$700,000 USDC** (scale later)
- `maxOut` matching vault policy

## Target vaults (submit to each curator)
1. Gauntlet USDC Prime — `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61`
2. Steakhouse Prime USDC — `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2`
3. Steakhouse USDC — `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183`
4. Steakhouse High Yield USDC v1.1 — `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F`

## On-chain steps for curator
1. Enable RSS/USDC market on vault (submitCap / acceptCap)
2. `PublicAllocator.setFlowCaps(vault, [{id: MARKET_ID, maxIn, maxOut}])`
3. Ensure Public Allocator is vault allocator

## Contact / submit
- Morpho curator Discord / Gauntlet + Steakhouse listing forms
- Packet prepared by Kingdom Scribe for King Errick

## Borrower fire (after maxIn > 0)
Atomic: `reallocateTo` → `supplyCollateral(RSS)` → `borrow(USDC → KingVault 0xA1aF…832a)` — see `FireReallocateBorrow.s.sol`
