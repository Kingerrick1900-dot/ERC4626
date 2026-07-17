# USDC Lenders — unlock Phase C

King Pod Option A is live on Base. Collateral is overbuilt at the Crown oracle ($0.05 RSS).

## Why lenders matter
The money market vault (`sUSDC`) currently has **0 idle USDC**.  
King’s **maxBorrow ≈ $734M**, but borrowable cash must come from **external USDC deposits**.

## How to lend
1. Approve USDC to `sUSDC` = `0x4af86ac17eb6f12588b2f3b70969f304933d1021`
2. Call `deposit(assets, receiver)` on sUSDC
3. Receive sUSDC shares

## Then Phase C
Once idle USDC > 0, King runs:

```bash
PRIVATE_KEY=… ./script/phase-c-borrow.sh <amount_6_decimals>
```

12% team cut (policy) applied by the script when `TEAM` ≠ King.

## Risk (plain)
This is a Crown-policy oracle market, not Morpho canonical risk. Lenders underwrite oracle + smart-contract risk.
