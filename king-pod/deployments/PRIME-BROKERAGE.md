# PRIME BROKERAGE STACK — Bound Landing Collateral

**Branch:** `cursor/prime-brokerage-stack-4f7f`  
**Doctrine:** Lock float (don’t sell) → create USDC idle via solvers/LitePSM → draw → fees repay.

## Chassis

| Contract | Role |
|--|--|
| `CrownBoundLandingCollateral` | Lock eUSD/gUSD as **non-liquidatable** coll; capacity = coll × LLTV |
| `CrownPrimeCredit` | USDC loan pool; idle from solvers/LitePSM supply |
| `CrownLitePsm` | Pre-mint eUSD sell buffer; `sellGem` USDC→eUSD feeds credit |
| `CrownPrime7683Fill` | ERC-7683-style solver fill; discounted eUSD; USDC → credit + fee |
| `USDCBorrowRouter` | Draw loans against float when idle exists (`armed=false` until King) |
| `SelfRepayingTreasury` | Fee sink; auto-repays credit debt |

## Physics (honest)

1. **Locking float creates capacity, not USDC.** `$22M × 30% = $6.6M` room ≠ cash.
2. **USDC idle** arrives only when solvers/`sellGem` bring real dollars into `CrownPrimeCredit`.
3. **Router draw** reverts `IdleMiss` if credit has no cash — no fake payroll.
4. **Treasury** sweeps protocol fees → `repay` → frees collateral capacity.

## Wire order (King)

1. Deploy (`FirePrimeBrokerage`)
2. `lockEusd` / `lockGusd` on collateral
3. `psm.seedEusd` (open LitePSM door) + optional `fill7683.seedFillBuffer`
4. Solvers fill / users `sellGem` → credit idle grows
5. `router.setArmed(true)` then `draw` / `drawToPsm`
6. Fees → `treasury.sweep` auto-repays

## Test

```bash
forge test --match-contract PrimeBrokerageTest -vv
```

## Deploy (Base)

```bash
KING_GO=1 FIRE_PRIME=1 PRIVATE_KEY=0x… \
  forge script script/FirePrimeBrokerage.s.sol:FirePrimeBrokerage \
  --rpc-url $BASE_RPC_URL --broadcast -vvv
```

No weak plans. Own bank: lock float → pull dollars in → borrow → yield clears debt.
