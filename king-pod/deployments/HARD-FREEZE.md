ZERO USDC IN KINGDOM — freeze until external source

LIVE FIRE attempted:
- morpho.borrow($500k USDC → Landing) on ELE/USDC 0xa4ec…
- tx: 0x13495c1361db75393163a25b3bdab10c292424333ee0fd91fcf08e0c294dea6e
- revert: insufficient liquidity
- Landing USDC unchanged: 10370469 ($10.37)

PA does not auto-run inside borrow(). No other yELE market to reallocateTo from.
