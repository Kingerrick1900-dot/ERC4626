ZERO USDC IN KINGDOM — freeze until external source

PA → borrow sequence executed (docs order):
1. yELE isAllocator(PA)=true · fee=0
2. Morpho API marketById ELE/USDC 0xa4ec…:
   - reallocatableLiquidityAssets = 0
   - publicAllocatorSharedLiquidity = []
   - liquidityAssets = 3
3. No withdrawals array possible → reallocateTo NOT fired (empty sources)
4. Prior borrow tx 0x13495c… reverted insufficient liquidity

Status: PA cannot fund this market. External USDC required.
