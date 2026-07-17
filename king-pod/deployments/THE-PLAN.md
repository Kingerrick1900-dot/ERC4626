# THE PLAN — LOANS + TOKENS (arb killed)

## Plain English
King has RSS tokens. Those tokens are the collateral.
Morpho is the bank. Bank gives a USDC loan against the RSS.
USDC goes into the vault. The loan stays open. RSS stays locked.
Not a sale. Not a lucky arb shot. A credit line against the token.

## Live numbers
| Item | Number |
|------|--------|
| RSS on King | ~18.49M |
| Oracle | $0.05 / RSS |
| Collateral value | ~$924,722 |
| LLTV | 77% |
| Max loan | ~$712,036 |
| Safe band (HF≈1.4) | ~$508,597 |
| Safe band (HF≈2) | ~$356,018 |
| Market loan float now | ~0 (must seed S before borrow) |

## Fire (one contract)
`CrownPowerBorrow.powerBorrow(seedUsdc, rssCollateral, borrowUsdc)`
1. Pull seed USDC from King → supply Morpho (loan float)
2. Pull RSS from King → post collateral
3. Borrow USDC → **vault**
4. STOP. Debt held.

## Size
`borrowUsdc <= seedUsdc` and inside LLTV. King picks the number.

## Not this
- Flash arb
- Elite-close (zeros debt, eats fill)
- Self-lend circular book ($0 vault)
- Dust loops

## Rule
No deploy / no fire without King greenlight.
