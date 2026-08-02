# Engineer: ELE/USDC cleanse via yELE redeem

**Choice:** engineer the position (not wait for external USDC; not partial bleed).

## Why

- yELE ≈ Morpho ELE/USDC debt ≈ **$13.002M** — circular self-seed.
- `maxWithdraw` while debt open ≈ **$50** (market idle only).
- WETH/USDC yELE cap still pending until `validAt` `1785092927` (~2026-07-26T19:08:47Z) — realloc cleanse blocked.
- Morpho holds **~$179M** USDC → flash size is fine.

## Path (`CLEANSE_REDEEM=1`)

1. Morpho flash USDC ≈ debt + $5  
2. Repay King ELE/USDC debt  
3. Withdraw all ELE collateral → ops → King  
4. `yELE.withdraw(maxWithdraw)` burning King shares → repay flash  
5. Dust gap (wei) topped from King USDC  
6. Leftover USDC → Landing; leftover yELE claim swept if liquid  

**Net:** Morpho book flat. ELE free on hot. Does **not** mint new ops USDC — circular cash cancels. Equity realized as free ELE.

## Fire

```bash
KING_GO=1 FIRE_OPS_FIVE=1 CLEANSE_REDEEM=1 forge script script/FireOpsFive.s.sol:FireOpsFive \
  --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

Fork: `forge test --match-contract EleCleanseRedeemForkTest -vv`

## Live (2026-07-24) — SUCCESS

| Field | Value |
|--|--|
| Ops | `0x42450B41F31ae82494D5088F3e49202659F6ec02` |
| ELE/USDC debt | **0** |
| ELE/USDC coll | **0** |
| Hot ELE | ~**100.00M** (freed Morpho coll + prior free) |
| Landing USDC | **0** (circular cash cancelled; no new ops USDC) |
| Note | Broadcast needs `--slow` on EIP-7702 hot (gapped-nonce otherwise) |
