# FIRE — King Fire Order (ZK matched)

**Mode:** FIRE · Base · ZK mandatory  
**Tx:** [`0x5e0514f969bff734615886c2da1039893154553a8a555614bfa6d54dd93dd641`](https://basescan.org/tx/0x5e0514f969bff734615886c2da1039893154553a8a555614bfa6d54dd93dd641)

---

## Executed

| Item | Value |
|--|--|
| CrownKingsFire | `0x16a3a6d50e80D70C873645789afCECf8B8b6aDC9` |
| CrownGateV2 | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| WalletGate | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` · `isProven(HOT)=true` |
| Mode | **fireMatched** (flash seed → draws repay flash) |
| Morpho borrow | **$1,000,000** USDC debt on gate |
| Crown Credit | **+$100,000** debt on HOT |
| Collateral | **222,521.94 RSS** retained on gate @ $50k oracle |

### Prior arming txs

| Step | Tx |
|--|--|
| Deploy CrownKingsFire | [`0x46c84f88…6276`](https://basescan.org/tx/0x46c84f889fac81f52642f8d5dd1c8d4c94cd6d0c359bbffc718aeb3b51776276) |
| Gate setOperator | [`0x880d3b79…a7e3`](https://basescan.org/tx/0x880d3b795492a8bb6280ada035d71ef89e26d9449ca67e1d302c1fc46dc9a7e3) |
| Credit setOperator | [`0xd80a8905…ccd0`](https://basescan.org/tx/0xd80a8905d2d42ef588935ad1d6a110b2be44fb3eabb3619f829000cb7f3dccd0) |
| **fireMatched** | [`0x5e0514f9…d641`](https://basescan.org/tx/0x5e0514f969bff734615886c2da1039893154553a8a555614bfa6d54dd93dd641) |

---

## Note

Matched mode opens the commanded **$1M Morpho + $100k Credit** debts under ZK. Flash liquidity is seeded and drawn back to repay in-callback (named repay: Morpho.borrow + Credit.operatorBorrowTo).  

`fireWithCover()` remains available when HOT holds ≥ $1.1M USDC to land draws on Landing instead of matching.

```
KINGS_FIRE=DONE
ZK_SHIELD=1
BORROW_USDC=1000000e6
CROWN_CREDIT=100000e6
MODE=matched
TX=0x5e0514f969bff734615886c2da1039893154553a8a555614bfa6d54dd93dd641
```
