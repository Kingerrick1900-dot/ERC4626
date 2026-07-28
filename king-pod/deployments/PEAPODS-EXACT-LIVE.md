# Peapods-exact self-lend — LIVE

**King GO** — follow Peapods plan exactly (not starve). Base 2026-07-28.

## Playbook (L1–L7)

| Step | Peapods | Kingdom live |
|--|--|--|
| L1 | Flash pairing asset | Morpho flash **$1,000,000** USDC |
| L2 | Supply → receipt | **fUSDC** vault deposit (cash+borrows share price) |
| L3 | Wrap TKN + LP receipt | **pELE** wrap + UniV2 **pELE/fUSDC** LP |
| L5 | LP as collateral | `CrownPeapodsPair.supplyCollateral` |
| L6 | Borrow pairing asset | Borrow **$1M** USDC to seeder |
| L7 | Repay flash | Flash debt **$0** |

**Result:** vault util **100%** (PoD). LP arb surface live. Pool borrow remains.

## Addresses

| Piece | Address |
|--|--|
| pELE | `0xf2F808e3BEd62e4CbBB2c64e455641cbf7cED8F5` |
| fUSDC vault | `0x86bEB1cbeB7b352aB81Fae8Ced01AAd18183a3E8` |
| LP | `0x3C25Cd9574de4D3212eE10b22d793Cd10451d4b6` |
| Pair | `0x2d5BE1EADca80001EdFD34D3f13f24edAb2B17BB` |
| Seeder | `0x5f542322668A3D615e2c662E16133AB40714BD2A` |
| `selfLend` tx | [`0xd3954b85…84962`](https://basescan.org/tx/0xd3954b85c4cc0800857a21def11d5b681748ba89206bbf16409b1bb1b7e84962) |

## Verify

```
vault.cash        = 0
vault.totalBorrows = 1000000000000   // $1M
vault.totalAssets  = 1000000000000
pair.debt(hot)     = 1000000000000
util               = 10000 bps
hot ELE left       ≈ 74M
```

## Size

| | |
|--|--|
| USDC flash/borrow | **$1,000,000** |
| ELE wrapped | **1,000,000** |
| Soft $1 equal legs | yes |

## Note

Peapods `createPodAndAddLvfSupport` on their Base factory reverted in oracle ctor against kingdom ELE Uni pool — so the **exact L1–L7 mechanics** run on kingdom rails (Morpho flash + fUSDC + pELE + UniV2 + pair), not their IndexManager deploy path.

Matched PoD ≠ Landing payroll by itself; this lights the Peapods machine (util + LP surface) King ordered.
