# Free RSS from external loans — EXECUTED

**Status: DONE on Base.** Liquid RSS back on hot. External loan locks cleared.

## Result

| Bag | Before | After |
|-----|--------|-------|
| Hot free RSS | ~9.98M | **~14.98M** |
| OTC escrow `0x08DD…501a` | 5,000,000 RSS | **0** |
| CrownRssTrove `0xC499…3fFD` | 519.48 RSS coll + 400k eUSD debt | **0 / 0** |
| Morpho WETH/USDC dust | ~$0.20 debt + dust WETH coll | **0** |
| Morpho cbBTC/USDC dust | ~$0.40 debt + 771 wei coll | **0** |

## Txs

| Step | Tx |
|------|-----|
| `withdrawRss` 5M from OTC | `0x8b512241c4c39df82581fea80ca5a331721cac95b9cb3aef24d34e3529e16db1` |
| Mint 400k eUSD (repay ammo) | `0x9ba51c0b3fb52e28c39c65aa68aa88657bfe926e29a93c4d4f81bdf98a76dc93` |
| Approve trove | `0xd7ecc85b5e6f06fe3d34a597011c51e0afd422530dc95b906b67c3f350aa77ed` |
| Trove `repay` → free 519 RSS | `0xfecd0533945e2fb020ce700c07a44f6a72ee555773b442cbd9e471a71fb8448d` |
| Morpho WETH repay | `0x10c699a24dc0aa8534a475c5ea178f783b9f45a8f7418fec402bcabf25efdaa9` |
| Morpho WETH withdrawCollateral | `0xf590862088c5838b4f6117b61abb144992c914a0d6a3b43b5509f4c5ea7c3e30` |
| Morpho cbBTC repay | `0xe7af53601bf5e094bfdc6b5bd41ab80c05eef228add5a32479ab6785f7b681f3` |
| Morpho cbBTC withdrawCollateral | `0x97724d856e1aceb5f3fbdfc61a0acd194ece6ec0cc93399dc7ad6732b2853481` |

## Notes

- V1 KingPair still holds ~20.98B RSS (bootstrap LP — not freeable with current V1).
- Landing still holds previously minted eUSD from trove `open` (~700k) — separate from this free.
- Morpho RSS markets for hot remain supply/borrow/coll = 0.
