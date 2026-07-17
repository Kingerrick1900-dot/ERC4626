# 1 USDC → Steakhouse USDC vault (executed)

## Order
Add 1 USDC to Steakhouse USDC Morpho Vault `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183`.

## Done
- Approve + deposit **1,000,000** raw USDC from King hot
- Deposit tx: `0x52858e1db3064eb7c1e53ecfb21b8af5325765870b6bd224fedb99175df47534`
- Vault allocated into Morpho cbBTC/USDC book (Steakhouse’s existing markets)

## Honest physics
This deposit earns Steakhouse yield and gives King vault shares. It does **not** by itself:
- enable RSS on Steakhouse (`enabled=false`, `maxIn=0` still)
- fund yRSS pipe
- create idle USDC on King RSS market for PA → borrow → Cake

Steakhouse routes depositor USDC to markets **they** list. RSS is not listed there yet. Packet still required for that unlock. This drop is a Steakhouse position, not a yRSS depth fill.
