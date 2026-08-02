# Scroll eUSD rail — LIVE ops

**Cold:** `0xD42A5222DdEA6C097CBDc6e24273Da7DFEe24e93`  
**Landing:** `0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f`  
**Hot:** `0xca76AE9e29a5F01465D890dc30109cD58B78F864`

## Caps

| Action | Amount |
|--|--|
| Convert tranche | **100,000 eUSD** |
| Keep / cold | **≥545,000 eUSD** |

## Executed 2026-07-27

| Step | Tx | Result |
|--|--|--|
| Gas Landing | `0xc5d9e9f6ca00af71b3eff52a694e93dd9c98c44256eb4836c2ebb3d477cc6c5d` | 0.0012 ETH |
| **→ Cold** | `0x7299e7fac87622db1ea3b39d9e2a7cea5d83eb5cb370bf79727e2f65cb0e8fed` | **545,167.74 eUSD** |
| **→ Hot** (convert tranche) | `0xc3dba8c2d023b43b80863571db216d0c074d2eab4d19a6eed184598f34127437` | **100,000 eUSD** |

## Balances after

| Wallet | eUSD |
|--|--|
| Landing | **0** |
| Cold `0xD42A…` | **545,167.74** |
| Hot | **~100,001.30** (100k tranche + dust) |

## Convert 100k → USDC — blocked on depth

Uni eUSD/USDC pool has ~**$0.20** USDC. Aggregators return no route for 100k.  
**Will not** dump 100k eUSD into dust liquidity.

To finish convert: seed **~$100k USDC** on Scroll (PSM or pool), then redeem/swap the hot 100k tranche 1:1.

Gold CDP (100,001 kXAU) untouched.
