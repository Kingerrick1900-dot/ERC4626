# ZK Credit Pool B — LIVE

## Law
Public pool \(L\) on `CrownZkCredit`. Proven subject draws \(\le 70\% \times \$700k\), **USDC must hit Landing or revert**.

## LIVE Base
| | |
|--|--|
| Gate (wallet-bind) | `0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579` (`isProven=true`) |
| **CrownZkCredit B** | `0x5C60a79b02c1907d5d23aEBfe259c5bb9116798d` |
| Cap | \(0.7 \times \$700k = \$490{,}000\) |
| Path seed (Steak → L → Landing) | **\$1.000386** drawn |
| Landing USDC after | **\$2.043377** |
| credit `totalDebt` | 1000386 |
| credit USDC bal | 0 (fully drawn) |

## What B proved
ZK underwrite + `borrowMaxToLanding` works end-to-end.  
**What B did not create:** \$490k. \(L\) only had the Steak seed. **Systems must `supply(USDC)` for size.**

## System supply (next capital)
```bash
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" 0x5C60a79b02c1907d5d23aEBfe259c5bb9116798d <AMT> \
  --private-key $SYSTEM_KEY --rpc-url $BASE_RPC
cast send 0x5C60a79b02c1907d5d23aEBfe259c5bb9116798d \
  "supply(uint256)" <AMT> \
  --private-key $SYSTEM_KEY --rpc-url $BASE_RPC
# King draw:
cast send 0x5C60a79b02c1907d5d23aEBfe259c5bb9116798d \
  "borrowMaxToLanding()" --private-key $PRIVATE_KEY --rpc-url $BASE_RPC
```

## Fire
`KING_OK=1 FIRE_ZK_CREDIT_B=1 forge script script/FireZkCreditPoolB.s.sol:FireZkCreditPoolB --rpc-url $BASE_RPC --broadcast`
