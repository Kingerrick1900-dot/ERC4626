# Primary Fill — ZK Required

**We use ZK.** No advance without `isProven(king)`.

| | |
|--|--|
| **CrownZkAdvance** | `0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B` |
| Gate | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| kUSD for sale | **~699,994** |
| Landing (cold) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |

## Counterparty

1. `cast call GATE "isProven(hot)"` → **true**
2. Approve USDC → ZkAdvance
3. `advance(usdcAmt)` — USDC **straight to Landing**, kUSD to buyer
4. If King proof expires/invalid → **tx reverts** (`KingNotProven`)

Primary goal: Landing ≥ \$700k. This door is the ZK sword.
