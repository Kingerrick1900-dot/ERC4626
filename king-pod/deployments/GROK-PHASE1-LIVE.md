# Grok Phase 1 — LIVE ($13M)

**Status: FIRED on Base · ONCHAIN SUCCESS · FULL ASK**

## End state
| Field | Value |
|--|--|
| Seeder | `0xb71FBCf68e5446f4b96a016C5fF259332dC5eC5e` |
| Morpho ELE coll (hot) | **23,937,370.18** |
| Morpho USDC debt | **~$13,000,003.37** |
| HF (soft $1) | **~1.841** |
| LTV | **~54.3%** |
| yELEPAN-USDC TVL | **~$13,000,005.49** |
| Earn shares | Landing |
| feeRecipient | KingVault `0xA1aF…832a` |

## Path used
1. Wallet “Kingdom ELE” = **eUSD** `0xE8aA…` (not Morpho coll).
2. Moved eUSD → Landing; CDP `repay` (burns from Landing).
3. CDP `withdraw` → **~22.7M Morpho-ELE** to hot.
4. Tranche seed ~$793k, then upsize `phase1` to **$13M**.

## Key txs
| Step | Hash |
|--|--|
| eUSD → Landing | `0xbe809af7…b93b` |
| CDP repay (bulk) | `0xf8727b41…052c` |
| CDP withdraw ELE | `0xb2987509…e473` |
| First tranche `phase1` | `0xc009a71a…d3ac` |
| Upsize `phase1` → $13M | `0x6d2c6990…be3f` |
| feeRecipient → KingVault | `0x9e1c5196…1170` |

## Phase 2
ELE/WETH + ELE/cbBTC already self-looped (prior).
