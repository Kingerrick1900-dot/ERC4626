# Liquid ops — real USDC, not trapped shares

## Reality

yELE-K **$700k shares** on cold are **Morpho supply matched to king debt**. Not idle. Not redeemable until debt is repaid (flash unwind) or borrowers repay.

| Need | Status |
|--|--|
| Spendable USDC for ops | Landing ~$59 (needs `LANDING_KEY`) + dust idle |
| Free ELE | 14M on 91.5% — withdrawable now (hot) |
| ELE/USDC DEX | **none** — must create + seed |
| Unlock $700k to USDC | Cold signs + flash repay debt + redeem (nets deleverage unless ELE is sold) |

## Fire (hot)

```bash
KING_GO=1 FIRE_LIQUID=1 \
forge script script/FireLiquidOps.s.sol:FireLiquidOps \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
# optional: LANDING_KEY=0x… moves Landing USDC → cold
```

## Next phase (swap + unlock)

1. Put `LANDING_KEY` in env → real USDC to cold for bills.  
2. Create UniV3/Aero **ELE/USDC** pool (no timelock) seeded with that USDC + ELE.  
3. Cold: approve unwind / send yELE-K shares to hot.  
4. Flash: repay pot debt → redeem shares → USDC → sell ELE as needed for ops float → repay flash.
