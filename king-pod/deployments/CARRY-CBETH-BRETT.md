# Carry live: ETH → cbETH → Morpho → yRSS/BRETT

## Path
1. Aerodrome `swapExactETHForTokens` WETH→cbETH
2. Morpho `supplyCollateral` on cbETH/USDC **86% LLTV**
3. Morpho `borrow` USDC at **60% LTV** (safe vs 86%)
4. yRSS `deposit` → supply queue BRETT-first

## Market
```
cbETH/USDC = 0x1c21c59df9db44bf6f645d854ee710a8ca17b479451447e9f56758aee10a2fad
cbETH      = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22
oracle     = 0xb40d93F44411D8C09aD17d7F88195eF9b05cCD96
router     = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43
```

## Txs (hot)
- swap `0x51990e46…1be7`
- approve cbETH `0x31d5359f…13d5`
- supplyCollateral `0x34368b34…3886`
- borrow `0xfb005e64…c973`
- approve USDC `0xf50f319b…1a1f`
- yRSS deposit `0x19e8cbe8…f624`

## Economics
cbETH keeps staking yield as collateral · borrowed USDC earns on BRETT · KingVault takes 10% of yRSS performance · net carry positive when BRETT supply APY > Morpho borrow APY.

## Floors
Hot USDC floor kept (~$1.20). Gas ETH reserve left on hot.
