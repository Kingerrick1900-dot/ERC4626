# Curator Packet — ELE/USDC PA maxIn (send today)

**Market:** Elepan / USDC · LLTV 77%  
**Id:** `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc`  
**Loan:** USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`  
**Coll:** Elepan `0x50639C42E2FFDEC4F68FB468968a55b3Af944583`  
**Oracle:** Fixed $1 `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` (burned owner pattern)  
**IRM:** AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687`  
**Borrower / coll poster:** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
**Vault already live:** yELEPAN-USDC `0x61bfD6F7df1f72427F472144d043c25d742D145E` (~$14M)

## Ask
Set Public Allocator flow caps on this market:

| Field | Request |
|--|--|
| `maxIn` | **$700,000** first · scale to **$5,000,000** |
| `maxOut` | match vault risk policy |

PA: `0xA090dD1a701408Df1d4d0B85b716c87565f90467`

## Why this book
- Collateral posted: **~40.1M Elepan** (~$40M @ $1 oracle)
- Active borrow: **~$14M**
- Unused LLTV room: **~$16.9M**
- Isolated market · fixed oracle · King-curated MetaMorpho vault already routing USDC here

## On first maxIn > 0
King fires PA reallocate + Morpho `borrow` → Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` same path as `FireElepanBorrowUsdc`.

## Targets
Gauntlet USDC Prime · Steakhouse Prime / USDC · Moonwell Flagship USDC · other Base USDC MetaMorpho curators.
