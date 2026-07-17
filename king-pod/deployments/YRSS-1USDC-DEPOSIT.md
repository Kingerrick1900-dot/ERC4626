# 1 USDC → yRSS pipe (executed)

## Order
Add 1 USDC to yRSS — the pipe we control.

## Done
- Approve + deposit **1,000,000** raw into `0xF80C0529bD94C773844E459853CD91B9263dD525`
- Deposit tx: `0x72dccb465ad0996708786055d2753d292122e8929e787d62b9bc62032a182274`
- yRSS totalAssets ≈ **2.000007** USDC (prior dust + this drop)
- Allocated into Morpho cbBTC/USDC (supply queue)

## Next when sized
PA `reallocateTo` from yRSS cbBTC/WETH → RSS → borrow to Cake (SpoilFire / FirePositionSeed700k).
