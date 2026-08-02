# Kingdom Gold Lane — sovereign backing (no king loan)

Institutional gold credit surface on Base. **The King does not borrow against gold.**  
kXAU is held free as sovereign backing; Morpho markets stand ready for the nation / vault — not a royal leverage loop.

## Live stack

| Piece | Address / value |
|--|--|
| **kXAU** | `0x76822B470DeC1b94Df4219727288e7a196224853` |
| Kingdom oracle | `0xCf2BC42FC9d158CCd77462c24670F17Cc57dBEd0` · **$10** (`1e35`) |
| Chainlink XAU/USD (Base) | `0x5213eBB69743b85644dbB6E25cdF994aFBb8cF31` |
| XAU Morpho ref oracle | `0x69F29e7Ce307df6F8412B115b242EC2791f5C40E` (~$4,054/oz scale) |
| GOLD **91.5%** market | `0xe433538a1eafb9ae985f6962435f6b14a1e27d50f8f30cab99b517f68b5e23da` |
| GOLD **77%** market | `0x339d9b5aca7606998f646723f3f978fa1213ecc9ff60d0a02f2f92ecac4e8d4b` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| yELE caps | **$14M** submitted each · `validAt` ~**1785215947 / 1785215949** (timelock → `acceptCap`) |

## Policy

| Rule | |
|--|--|
| King Morpho gold borrow | **NONE** |
| King gold collateral posted | **NONE** |
| Sovereign kXAU on hot | **100,001** free (treasury receipt units) |
| Markets | Open / empty — ready rails |
| Primary quote | Kingdom **$10** |
| Spot reference | Chainlink XAU (~$4,054/oz) for future oracle upgrade path |

## What this is

- **kXAU** — kingdom gold receipt (8dp), mintable by King, held as backing  
- **Morpho GOLD/USDC** at 77% and 91.5% — credit venue for depositors / yELE after caps  
- **Not** a PAXG wrap; not a king self-seed loan  

## Accept caps (after timelock ~48h)

```bash
# when pendingCap.validAt reached
cast send 0x61bfD6F7df1f72427F472144d043c25d742D145E \
  "acceptCap((address,address,address,address,uint256))" \
  "(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,0x76822B470DeC1b94Df4219727288e7a196224853,0xCf2BC42FC9d158CCd77462c24670F17Cc57dBEd0,0x46415998764C29aB2a25CbeA6254146D50D22687,915000000000000000)" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
# repeat for LLTV 770000000000000000
```
