# Elepan Self-Seed — LIVE on Base

**Status: FIRED · ONCHAIN SUCCESS**

## End state
| Field | Value |
|--|--|
| Seeder | `0xed6149dE4B8D17DA2DF7d1B5E67c950EFd8aeF74` |
| yELEPAN-USDC TVL | **~$9,000,002** |
| Hot yELEPAN shares | `9e24` (≈ $9M assets) |
| Morpho Elepan coll | **13.0M Elepan** |
| Morpho USDC borrow | **~$9,000,000** |
| Market supply / borrow | **~$9.000002M / $9.0M** |
| Hot USDC | ~$1.61 (flash closed — unchanged) |
| Free Elepan left (hot) | **~61.72M** |

## Txs
| Step | Hash |
|--|--|
| Deploy `CrownElepanSelfSeed` | `0x4e3f8384a3f5b985d4b81e8b71e962d6cf155f2c4421302d39d39b50cef78639` |
| Morpho `setAuthorization` | `0x52e062b56266a7c468f1bba569f8cf9ef466b3d661c8988710736ad4e6df450b` |
| Elepan `approve` | `0x8e71723a7de9513e918e1c23309e2bdf9a01efa8a00a8e0f39ff5ff8f037943f` |
| `selfSeed(13M, $9M)` | `0x94465542a55acaab9409b04c5d29546504161ee93ff4624d4a8c7a028da1a0d5` |

## Path used
```
flash Morpho USDC (~$200M inventory)
  → yELEPAN.deposit $9M
  → borrow $9M vs 13M Elepan coll
  → repay flash
REPAY_SOURCE = Morpho.borrow(ELE_USDC)
```

## Next (needs new King GO)
- External / PA idle on top → borrow spendable USDC to Landing  
- Own emitter / Merkl amp  
- PSM + ELE/USDC pool when Landing USDC exists  
