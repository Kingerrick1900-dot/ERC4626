# Extract $500k — Loan Completion

**Primary:** atomic matcher complete → Landing.

See `LOAN-COMPLETE-LIVE.md` + `zk-liquidity-match.json`.

```bash
KING_GO=1 FIRE_LOAN_MATCH=1 ASK_USDC=500000000000 \
  MATCHER_KEY=$MATCHER_KEY \
  forge script script/FireMatcherComplete.s.sol:FireMatcherComplete \
  --rpc-url $BASE_RPC --broadcast --slow
```

Completer: `0x12514e1f999131eA78D402a7258b67A65F9342Ff`  
Auto-draw: `0xE7e7008D71387a79Bf57F1E5Ab75534d4b3DA34A`

Fork proof: `forge test --match-contract LoanCompleteForkTest -vv`
