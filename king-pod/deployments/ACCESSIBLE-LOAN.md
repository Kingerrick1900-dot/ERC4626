# Accessible Loan — spendable USDC only

**King law:** No Morpho debt unless King can access spendable funds for the asset put up.

## What this is

`FireAccessibleLoan.s.sol` — post RSS collateral → `borrow(..., receiver = Hot)` → **USDC lands in Hot wallet**.

- No flash
- No yRSS self-seed
- Hard `require(walletGain >= borrow)` — fails if funds don't land

## Live Morpho reality (checked)

| Market | Idle USDC borrowable now |
|--------|--------------------------|
| RSS77 | **~$1.00** |
| RSS91 | **~$1.00** |
| BRETT | **~$1.05** |
| Foreign vault PA into RSS77 | **$0** (only yRSS dust ~$0.35 reallocatable) |

**There is no $500k accessible Morpho loan on-chain right now.** Caps on yRSS PA (~$700k) do not create USDC — they only move USDC the vault already holds. yRSS TVL is dust.

## How a real $500k accessible loan appears

1. **External Morpho lenders** supply USDC to RSS77 → idle rises → `FireAccessibleLoan` / `capture-accessible-loan.sh` borrows to **Hot**
2. **Desk / bond / dutch fill** → USDC to Landing (commerce, not Morpho loan)
3. **Foreign vault maxIn** (Gauntlet/Steakhouse) → PA can pull their liquidity into RSS77 → then accessible borrow

## Fire (when idle is real)

```bash
# Dry — shows idle vs want
KING_OK=1 KING_GO=1 FIRE_LOAN=0 forge script script/FireAccessibleLoan.s.sol --rpc-url $BASE_RPC

# Fire when idle >= size — USDC to Hot ops wallet
KING_OK=1 KING_GO=1 FIRE_LOAN=1 BORROW_USDC=500000000000 \
  forge script script/FireAccessibleLoan.s.sol --rpc-url $BASE_RPC --broadcast

# Daemon — auto-borrow to Hot when idle hits $100+
AUTO_FIRE=1 bash script/capture-accessible-loan.sh
```

## Forbidden forever

`FireFlashAttack500` / fortress self-seed — debt with **$0** wallet USDC. Requires `ALLOW_FORTRESS_DEBT=1`. Default: revert.
