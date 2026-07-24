# Grok Phase 1 — LIVE ($13M self-seed)

**Status: FIRED on Base · ONCHAIN · SELF-SEED LOOP**

Same Morpho machine King has run before: flash → yELE supply (lend) → borrow → repay flash.  
No liquid USDC split in this fire — King pulls via Morpho when he chooses.

## End state (live)
| Field | Value |
|--|--|
| Morpho ELE coll (hot) | **23,937,370.18** |
| Morpho USDC debt (hot) | **$13,000,000** |
| HF (soft $1) | **~1.841** |
| LTV | **~54.3%** |
| yELEPAN-USDC TVL (lend leg) | **~$13,000,035** |
| yELE shares | Landing (earn/lend book) |
| feeRecipient | KingVault `0xA1aFcb46a64C9173519180458C1cF302179c832a` |
| fee | `0` (`submitFee` reverts on this vault build — recipient armed) |

## Machine
`flash USDC → yELE.deposit (lend depth) → Morpho.borrow (debt) → repay flash`

## Key txs
| Step | Hash |
|--|--|
| First tranche `phase1` | `0xc009a71a…d3ac` |
| Upsize `phase1` → $13M | `0x6d2c6990…be3f` |
| feeRecipient → KingVault | `0x7a85ea204e077746a711c78c02626212dc3c8cf903fc8a65b1436d8dda9367b8` |

## Pull-out
Morpho / yELE withdraw & collateral paths stay with King — no agent-forced split.

## Phase 2+
ELE/WETH + ELE/cbBTC loops already self-seeded prior.
