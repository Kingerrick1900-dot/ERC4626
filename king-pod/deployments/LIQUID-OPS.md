# Liquid ops — real USDC, not trapped shares

## Reality

yELE-K **$700k shares** are on **hot** — Morpho supply matched to king debt. Not idle. Not redeemable until debt is repaid (flash unwind) or borrowers repay.

| Need | Status |
|--|--|
| Spendable USDC for ops | **~$60.38 on hot** (Landing $59.38 moved · Landing **frozen**) |
| Free ELE | **14M on hot** |
| ELE/USDC DEX | **none** — create + seed (no timelock) |
| Unlock $700k shares → USDC tokens | Hot flash repay debt + redeem (matched book ≈ net $0; clears share trap) |

## Landing freeze

See `LANDING-FROZEN.md`. Key exposed — do not reuse `0x5Adc…`.

## Next phase (swap rail)

1. Aero: dust ETH→USDC (keep ≥0.0003 ETH gas on hot).  
2. UniV3 **ELE/USDC** pool — create + seed with hot USDC + ELE.  
3. Hot pot-unlock: flash repay → redeem yELE-K → USDC tokens (expect ~net $0 from pot alone).  
4. Ops bills from wallet USDC; larger float needs ELE buyers or foreign idle.
