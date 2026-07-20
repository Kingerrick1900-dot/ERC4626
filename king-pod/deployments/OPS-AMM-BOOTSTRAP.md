# Ops AMM Bootstrap — RSS/USDC (when seed USDC ready)

**Status:** Checklist armed. No pool exists on Base yet (UniV3/Aero probed empty).

## Elite sequence (when kingdom holds seed USDC)

1. Create Aerodrome volatile pool RSS/USDC  
   - Factory `0x420DD381b31aEf6683db6B902084cB0FFECe40Da`  
   - `createPool(RSS, USDC, false)`
2. Add liquidity via Aero Router `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43`
3. Sell sized RSS with `swapExactTokensForTokens` + slippage cap (e.g. 1–3%)
4. Proceeds → Landing  
5. Keep Ops Desk live for block size; AMM for discovery

## Seed sizing (example)

| Seed USDC | RSS at $1 | Notes |
|--|--|--|
| $25k | 25k RSS | thin discovery |
| $100k | 100k RSS | serious desk seed |
| Ops sell | up to 500k RSS | into deeper book |

## Rule

Do not dump 18.5M into an empty pool. Desk-first for $500k; AMM second for ongoing liquidity.

## Doctrine

Same as Steakhouse/Morpho: **create the venue** when the book needs exit liquidity — don’t wait for charity.
