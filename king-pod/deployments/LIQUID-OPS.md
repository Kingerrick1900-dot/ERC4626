# Liquid ops — completed inventory

| Rail | Status |
|--|--|
| Hot USDC | **~$60.75** (`OWN-STACK-CASH-LIVE.md`) |
| Hot ELE | **~59.75** free |
| TEN $10/91.5% | ~14M ELE coll · $700k supply/borrow matched · refinance script **fork-proven** |
| ELE77 | ~86M ELE · ~$50M matched |
| ELE/USDC pool | exists `0x4615a3E4…7410` — LP unwound to hot |
| Landing | frozen |

## Completable engineering (done)

- Own-stack cash fire  
- `FireTenRefinanceSeed` + fork test → **~$700k USDC** when hot holds wire ≥ debt (repay-by-shares)  
- Packet: `SEED-700K-PLAYS.md`  

## Live fire refinance (needs USDC on hot ≥ ~$700k)

```bash
KING_GO=1 FIRE_TEN_REFANCE=1 \
forge script script/FireTenRefinanceSeed.s.sol:FireTenRefinanceSeed \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```
