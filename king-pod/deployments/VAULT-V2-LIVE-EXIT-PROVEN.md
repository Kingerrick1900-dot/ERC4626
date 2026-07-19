# Live gas-only exit — PROVEN on Base

**Mode:** Morpho flash fee 0. No USDC prefund. Gas only.

## Result: PASS

| Check | Result |
|-------|--------|
| `forceDeallocate` at drained util | **PASS** |
| Vault shares on freer after | **0** |
| Freer Morpho position | **0 / 0 / 0** |
| RSS returned to hot | **unchanged ~18.5M** |
| Penalty restored | **1%** |
| USDC prefund | **$0** |

## Contracts / txs

| Item | Value |
|------|--------|
| Freer | `0xF26a330505Ec3192107E91f895e0d95eaB72640e` |
| Test size | $100 USDC (flash $200) |
| `run` tx | [`0x88b2badd…77e727`](https://basescan.org/tx/0x88b2badd041b8787565f0996ece5736418e5770f74eece109c1cf6973b77e727) |
| Penalty → 0 | [`0x7e34ce85…78a7fd`](https://basescan.org/tx/0x7e34ce85faef7d3b07f409e6bf29661a0358423372ebff72b7d8cf968078a7fd) |
| Penalty → 1% | [`0xa6ab5624…9a4c05`](https://basescan.org/tx/0xa6ab5624a30d504df593ab08874338a6d69c0d187b06a765be4276b6669a4c05) |

## Flow

1. Penalty temporarily **0** (clean flash close)
2. Flash $200 → deposit $100 → drain with RSS borrow → IKR supply → `forceDeallocate` → withdraw → close Morpho → repay flash
3. RSS back to hot
4. Penalty restored to **1%**

## Post-state

- Hot RSS: ~18.5M (same)
- Hot USDC: dust (~$0.10)
- Landing USDC: $1 (unchanged — gas-only path is zero-sum for USDC)
- Vault `totalAssets`: ~$1 (dead seed)
- Penalty: 1%
