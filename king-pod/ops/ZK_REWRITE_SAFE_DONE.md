# Safe Morpho → CrownZkMorphoRail rewrite DONE

- Safe auth HOT: tx `0x73f15247292ada66de0ed5a5f7f0234bf0f2daa4517418a09c832290e5a4ef54` (nonce 1, Landing + 0x898D)
- Morpho withdraw Safe→HOT: `0xaf40b873fbb782b78c25a54cd7f269c28c8bfed3a1c228d0849c9dd9accbc67d`
- zkSupply via rail onBehalf Safe: `0x1e603e21c7d0d7488713b029de0135e0c65e47e386b846d5c20c38a661f4b3d3`
- Rail: `0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3`
- Amount: ~1.62445e27 eUSD (Safe book) + prior HOT spoil in `totalSupplied` ~1.925e27
- Guards: isProven(HOT), isProven(Safe), bordersSecure all true at fire
