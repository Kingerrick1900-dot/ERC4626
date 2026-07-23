# Native Token Vault (Elepan CDP) — BUILD SPEC

**Status:** CODE + FORK TESTS. **NO LIVE DEPLOY** until King `KING_GO=1 FIRE_CDP=1` and pre-fire checklist PASS.

**Pattern:** Maker-style CDP (native mint). Morpho Vault V2 remains the separate lending rail — this module is self-sufficient and King-only.

## Addresses (after deploy — TBD)
| Piece | Value |
|--|--|
| Collateral | Elepan `0x50639C42…4583` (hot bag) |
| Oracle | Soft $1 `0xe290…cf19` |
| eUSD | deploy via script |
| CDP vault | deploy via script |
| Owner | hot `0x6708…a7d1` |

## Published params (fixed at launch)
| Param | Value |
|--|--|
| Liquidation ratio | **150%** (`1.5e18`) |
| Safety floor (mint / partial withdraw) | **155%** (`1.55e18`) |
| Stability fee | **5%/yr** (500 bps) |

## Core mechanic
1. `deposit(elepan)` — lock coll  
2. `mint(eusd)` — within safety floor  
3. Stability fee accrues (`accrue` / on touch)  
4. `repay` → unlock; `withdraw` partial anytime if HF ≥ floor; `close` full exit  

## CRITICAL — no full lock
- Partial `withdraw` always (no cooldown) if `previewWithdrawHf ≥ safetyFloor`  
- Full unlock when debt = 0  
- Reverts `UnsafeHf` if withdraw would breach floor  
- **Verified in** `test/CrownElepanCdpVault.t.sol` (`test_partial_withdraw_*`)

## Pre-fire checklist
- [ ] Confirm this CDP track (not Morpho V1 MetaMorpho)  
- [ ] Morpho V2 `forceDeallocate` penalty non-zero (separate rail — already live on WETH V2)  
- [ ] One test forceDeallocate tx hash (V2 rail)  
- [ ] Gas top-up on hot  
- [ ] Partial withdrawal tested on **deployed** vault (after GO deploy)  
- [ ] `forge test --match-contract CrownElepanCdpVaultTest` PASS locally  

## Fire (King only)
```bash
cd king-pod
KING_GO=1 FIRE_CDP=1 forge script script/FireElepanCdpVault.s.sol:FireElepanCdpVault \
  --rpc-url $RPC --broadcast --slow
```

## Contracts
- `src/CrownElepanUsd.sol` — eUSD (vault minter only)  
- `src/CrownElepanCdpVault.sol` — King CDP  
- `script/FireElepanCdpVault.s.sol` — deploy  
- `test/CrownElepanCdpVault.t.sol` — partial withdraw + fee + close  
