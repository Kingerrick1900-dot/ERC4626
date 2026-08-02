# ELEPAN $17.5M SELF-SEED — LIVE

**King GO 🐘👑** — 2026-07-28 Base.

## Locked numbers

| Field | Value |
|--|--|
| ELE collateral | **25,000,000** (raw `2500000000000000`) |
| Soft LTV | **70%** |
| ASK / flash / pool borrow | **$17,500,000** USDC |
| Free ELE left on hot | ~**75M** |
| End flash debt | **$0** |
| End Morpho pool borrow | **~$17.5M** |
| Landing USDC after seed | **3 wei** (matched book ≠ payroll) |

## Path

1. Post 25M ELE coll on Morpho ELE77 (onBehalf hot)
2. Flash $17.5M USDC from Morpho inventory (~$187M)
3. **Direct `Morpho.supply`** loan USDC (bypass yELE ELE77 **$14M** supply cap)
4. `Morpho.borrow` $17.5M onBehalf hot → repay flash
5. Flash debt 0; matched supply+borrow book remains

## Fix that unlocked the fire

Prior attempt reverted on `morpho.supply` inside `onMorphoFlashLoan`.
Cause: Morpho Blue ABI is `supply(params, assets, shares, onBehalf, data)` — `shares` was missing, so calldata was garbage.

## Live addresses / txs

| Item | Value |
|--|--|
| Seeder | `0x51BCEc05919281E88Eb3f321100E7a65AC3d0E2e` |
| Market ELE77 | `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc` |
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| `selfSeed` tx | [`0x1854fb0d04a4c47819d1b9cedb3bada0e9eceb8ca264743a3cca4ed80f6fb5ec`](https://basescan.org/tx/0x1854fb0d04a4c47819d1b9cedb3bada0e9eceb8ca264743a3cca4ed80f6fb5ec) |
| Deploy seeder | `0xefd615daebbfe4b9e65acbbc1d0b995e5b1dc66523e543b90710416564204fd5` |
| Auth seeder | `0x867de8284c0aa51a611390f6b4283689f5ed16f73a740d1bfe7e444f9e26e49a` |

## On-chain verify (post-fire)

```
position(hot): supplyShares≈1.748e19, borrowShares=1.75e19, coll=2.5e15 (25M ELE)
market:        supplyAssets≈17.5e12, borrowAssets=17.5e12 ($17.5M / $17.5M)
hot ELE:       ≈75M
hot USDC:      dust (flash repaid)
Landing USDC:  3
```

## Truth

Matched flash self-seed lights the ELE77 book. It does **not** put hard USDC on Landing.
Ops payroll (≥$500k Landing) still needs a separate engineered extract — not buyer-wait.
