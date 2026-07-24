ZERO USDC IN KINGDOM — freeze until external source

Idle check (direct, not API):
- yELE has no idle()/idleBalance() (MetaMorpho)
- idle = USDC.balanceOf(yELE) = 0
- totalAssets ≈ $13.001M (all in Morpho ELE/USDC, util ~100%)

No reallocateTo. No borrow.
