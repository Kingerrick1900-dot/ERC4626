# Spoils Fill — LIVE (millions rail)

**Contract:** [`0xC0cDd56e35Fe94935E057579B2Eaa5885989CbA6`](https://basescan.org/address/0xC0cDd56e35Fe94935E057579B2Eaa5885989CbA6)  
**Deploy:** [`0x9fd3ee72…09ce81`](https://basescan.org/tx/0x9fd3ee72668b6138a63917fc72e6277a7d22a12797e6862d9d5e8a485609ce81)  
**List:** [`0xb569e646…8f7941`](https://basescan.org/tx/0xb569e6460d452db452fd16f0ec958654116f4c05384266e45f8ce9b7da8f7941)

## Armed ask

| Field | Live |
|--|--|
| ELE escrowed | **13,234,972.67759499** |
| USDC ask | **$700,021.012831** |
| TEN debt covered | **$700,020.012831** |
| On fill → king | TEN supply spoil **~$700k USDC** to hot |
| On fill → filler | **13.23M ELE** |
| Morpho auth | fill contract authorized on hot |

## Machine

1. Filler `USDC.approve(fill, ask)` + `fill()`  
2. Atomic: repay TEN debt → withdraw king supply spoil → hot  
3. Escrowed ELE → filler  

No USDC required on hot first. Permissionless.

```bash
# Re-arm later (if cancelled / filled)
KING_GO=1 FIRE_SPOILS_FILL=1 SPOILS_FILL=0xC0cDd56e35Fe94935E057579B2Eaa5885989CbA6 \
forge script script/FireSpoilsFill.s.sol:FireSpoilsFill \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

## Code

- `src/CrownSpoilsFill.sol`
- `script/FireSpoilsFill.s.sol`
- `test/SpoilsFillFork.t.sol`
