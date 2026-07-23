# Elepan Moat — $2 USDC seed (LIVE)

**Fired:** 2026-07-23 · King-directed `$2` seed into owned Elepan/USDC Morpho book via `yELEPAN-USDC`.

## Result
| Piece | Value |
|--|--|
| yELEPAN-USDC TVL | **$2.00** (`2000000`) |
| Moat totalSupplyAssets | **$2.00** USDC |
| Moat totalBorrowAssets | **$0** |
| Hot USDC after | **~$1.61** (floor ≥ $1 kept) |

## Txs (Base)
| Step | Hash |
|--|--|
| approve | `0x76106a56de664167800fec9bc0c8072d1bd00bf5c9301f541097ad8f8ac05b01` |
| deposit $2 → yELEPAN-USDC | `0x62e0fe7819f2108c23953bcaec836616f72586d6378893c1d29abc1bdf52d09c` |
| reallocate → moat | `0x4d38b6f3a826676d41f71859028f9392b5976284b378d28fd40c3cfd013bee2a` |

## Addresses
| Piece | Address |
|--|--|
| Market | `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc` |
| yELEPAN-USDC | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Script | `script/SeedElepanMoatTwoUsdc.s.sol` |

## Law
Self-seed optics only — $2 idle depth, not free capital.
