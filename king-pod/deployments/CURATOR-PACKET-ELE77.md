# Curator packet — enable ELE77 maxIn ≥ $500k (Path B)

**From:** King Errick · Elepan / yELE curator desk  
**To:** MetaMorpho curators with Base USDC depth (Gauntlet USDC Prime, Steakhouse Prime / USDC / HY)  
**Ask:** Enable kingdom **ELE/USDC 77%** market + Public Allocator **maxIn ≥ $500,000** (preferably $700k–$5M)

## Why this is standard Morpho

Public Allocator just-in-time liquidity is the battle-tested Morpho borrower path: vault idle in WETH/cbBTC → `reallocateTo` destination market → borrower draws against posted collateral. No custom plumbing required on your side beyond market enable + flow caps.

## Market (Base · Morpho Blue)

| Field | Value |
|--|--|
| Market id | `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | ELE `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` |
| Oracle | Fixed $1 `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** |
| Utilization now | ~**100%** (supply APY magnet) |
| Kingdom vault already listing | yELE `0x61bfD6F7df1f72427F472144d043c25d742D145E` · cap $14M |

## Requested curator actions

1. `submitCap` / `acceptCap` — enable ELE77 on your USDC vault (size at your risk committee).  
2. PA `setFlowCaps`: **maxIn ≥ 500_000e6** (suggest **700_000e6**), maxOut per your policy.  
3. Keep WETH/cbBTC maxOut sufficient so PA can source ≥ $500k.

## What happens after maxIn > 0

1. Anyone (kingdom desk) calls PA `reallocateTo` → ELE77.  
2. King borrows against **already-posted ~2M ELE** collateral (headroom ~$840k).  
3. USDC lands on treasury Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`.  
4. Vault earns Morpho supply yield at elevated util — aligned incentive.

## Explicitly not requested

- No oracle change  
- No IRM change  
- No whitelist of borrower EOA beyond normal Morpho  
- No custody of kingdom keys  

## Contact / verify

On-chain proof of coll + borrow headroom: Morpho `position(ELE77, 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1)`.  
Kingdom GO packet: `LANDING-500K-GO.md`.
