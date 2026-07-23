# Multi-Collateral CDP — LIVE on Base

**Status:** WETH + cbBTC CDPs deployed; dust smokes PASS. Elepan vault unchanged.

## Shared eUSD (multi-minter)
| Piece | Address |
|--|--|
| **eUSD** | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| API | `setMinter(address, bool)` — both vaults authorized |

> Prior Elepan-only eUSD `0x2b87…7B99` / CDP `0x3b07…85eB` left as-is (no source/param change). Multi-coll track uses this new multi-minter eUSD.

## WETH CDP
| Piece | Value |
|--|--|
| Vault | `0x60033c198bb686cEA1BAAF5a5CDc7b6e3Ddc9BCF` |
| Oracle | `0x8A0187C0dB746907095BAA8Da42ea45582B808B1` (`MorphoUniV3Oracle`) |
| TWAP pool | WETH/USDC `0xd0b53D…F224` · **1800s** (same live source as Elepan/WETH loan ora) |
| LR / floor / fee | **130%** / **135%** / **5%/yr** |
| ZK gate | `0xca2a…3f30` |
| Smoke | **PASS** (deposit/mint/partial/close) |

## cbBTC CDP
| Piece | Value |
|--|--|
| Vault | `0xb7Be10165c7A3296Cb621478B3dD497c65Da28d5` |
| Oracle | `0x02f22f614f25b7A385617b5Ff3F6E9Ab0Bd301BC` |
| TWAP pool | cbBTC/USDC `0xfBB6…43ef` · **1800s** (same live source as Elepan/cbBTC loan ora) |
| LR / floor / fee | **130%** / **135%** / **5%/yr** |
| ZK gate | `0xca2a…3f30` |
| Smoke | **PASS** |

## Isolation
Three separate vault contracts — a fault in one never touches the others. No shared collateral pool.

## Tests
`forge test --match-contract "CrownWethCdpVaultTest|CrownCbbtcCdpVaultTest|CrownElepanCdpVaultTest"` → **26/26 PASS**
