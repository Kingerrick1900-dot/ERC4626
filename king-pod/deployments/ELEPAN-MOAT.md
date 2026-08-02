# Elepan Moat + yELEPAN-USDC — LIVE on Base

Mirror of old RSS moat + yRSS: **owned Morpho book** (soft $1 Elepan/USDC) + **USDC MetaMorpho** that allocates into it.

## Moat — Elepan/USDC Morpho market

| Piece | Address / Id |
|--|--|
| Oracle | `MorphoFixedElepanUsdcOracle` `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` |
| Price | **1e34** (Elepan 8dp @ soft $1 vs USDC 6dp) |
| Market id | `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc` |
| Loan / Coll | USDC / Elepan `0x50639C42…4583` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** |

Owned niche — no shared Chainlink herd. Soft $1 peg matches Elepan loan oracles.

## yVault — yELEPAN-USDC (LIVE)

| Field | Value |
|--|--|
| Vault | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Name / Symbol | King Elepan USDC Vault / `yELEPAN-USDC` |
| Asset | USDC `0x833589fC…2913` |
| Owner / Curator / Allocator | hot `0x6708…a7d1` |
| Fee | **10%** → Landing `0x5Adc…2357` |
| Timelock | **2 days** |
| Supply queue | Elepan/USDC market only |
| Supply cap | **$14M** USDC |
| Public Allocator | `0xA090…0467` (`isAllocator=true`) |
| PA admin | hot |
| PA fee | 0 |
| PA flow | maxIn=maxOut=**$700k** |

### How it works
1. Depositors `deposit` USDC into yELEPAN-USDC.
2. Kingdom / PA allocates into the owned Elepan/USDC Morpho market.
3. Borrowers post Elepan collateral → depth + fee shares to Landing.

### Scripts
| Script | Purpose |
|--|--|
| `FireElepanMoatYvault.s.sol` | Oracle + market + MetaMorpho bootstrap |
| `MorphoFixedElepanUsdcOracle.sol` | Soft $1 Elepan/USDC Morpho oracle |

```bash
# Vault already live — pass ORACLE_USDC + VAULT to skip create
KING_GO=1 FIRE_MOAT=1 \
  ORACLE_USDC=0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19 \
  VAULT=0x61bfD6F7df1f72427F472144d043c25d742D145E \
  forge script script/FireElepanMoatYvault.s.sol:FireElepanMoatYvault \
  --rpc-url $RPC --broadcast --slow --skip-simulation
```

## Law
Same as yRSS: magnet empty until depositors arrive. Self-seed ≠ free capital. Pay from fee/idle/external only.
