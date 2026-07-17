# Fleet-only recovery hunt — King's wallets UNTOUCHED

## Order
Leave King's funds where they are. Fleet team finds replacement USDC. No pulls from hot / Cake / Morpho King position / yRSS / desk.

## Live scan (Base Morpho)
- **cbBTC/USDC, WETH/USDC, cbETH/USDC:** zero positions with HF ≤ 1.02
- **HF ≤ 1 board:** dominated by USR/USDC + junk undercollateralized zombies (coll << debt). Firing those **loses** more USDC — not fired
- **Uni V3 USDC↔WETH roundtrip:** negative after fees — no arb edge this block

## Fleet
- Address: `0xcbD8Ac7e09aB6944A0Ae8f2DecaBbDbC8F3EC564`
- Gas only. King's USDC dust on fleet left alone per order.

## Status
Hunting. Will fire only when sim shows **net USDC profit** after gas. Profit receiver: King token/hot `0x6708…` (ops) or Cake receive-only if King orders.
