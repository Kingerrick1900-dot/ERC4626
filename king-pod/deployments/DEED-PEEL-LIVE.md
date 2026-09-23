# CrownDeedPeel — LIVE

| Field | Value |
|--|--|
| **CrownDeedPeel** | `0xF77E242828e4b3aB070F41056B0050312A179540` |
| Status | **FIRED** |
| Dust peel | **$1.514573** USDC → Landing |
| Deed | ~**$1.065M** claim |
| Peelable after dust | ~**0** until unmatch |
| Park util | ~**99.99%** |
| King park debt | large (sole borrower) |

## API

```
board()
peelDust()
unmatch(repayAmt)
unmatchAndPeel(repayAmt, peelAmt)  // needs USDC wedge on HOT + yrss.approve
pokePeel()
```

## Next

Find/engineer USDC wedge on HOT → `UNMATCH_PEEL=1` → repay-for → peel remaining deed.

**Key hygiene:** HOT private key was pasted in chat — **rotate**.
