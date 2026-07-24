# Loan Completion — LIVE

**King-side complete. Matcher finishes in one transaction.**

| Piece | Address / Fact |
|--|--|
| Completer | **`0x12514e1f999131eA78D402a7258b67A65F9342Ff`** |
| Auto-draw | **`0xE7e7008D71387a79Bf57F1E5Ab75534d4b3DA34A`** |
| Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Hot / King | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| ZK proof | `isProven` **true** · attest **$1M** · maxAsk **$700k** |
| Loan ask | **$500,000** USDC (`500000000000`) |
| Completer operator | **true** |
| Auto-draw operator | **true** |
| Draw path | `operatorBorrowTo(Landing)` — King-proven |

Fork-proven: `test/LoanCompleteFork.t.sol`  
Deploy txs: completer `0x0bc5bcc6…d16b` · auto-draw in `broadcast/FireDeployZkAutoDraw…/run-latest.json`

JSON: `zk-liquidity-match.json`

---

## Matcher — loan complete (atomic)

```bash
KING_GO=1 FIRE_LOAN_MATCH=1 ASK_USDC=500000000000 \
  MATCHER_KEY=$MATCHER_KEY \
  forge script script/FireMatcherComplete.s.sol:FireMatcherComplete \
  --rpc-url $BASE_RPC --broadcast --slow
```

```bash
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" \
  0x12514e1f999131eA78D402a7258b67A65F9342Ff \
  500000000000 \
  --rpc-url $BASE_RPC --private-key $MATCHER_KEY

cast send 0x12514e1f999131eA78D402a7258b67A65F9342Ff \
  "complete(uint256)" \
  500000000000 \
  --rpc-url $BASE_RPC --private-key $MATCHER_KEY
```

`complete(500k)` = prove check → pull USDC → `credit.supply` → `operatorBorrowTo(Landing)`.

---

## Alt fill (supply then poke)

```bash
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" 0xc4152c73824d85146B0f85a0b77E911D4769d936 500000000000 \
  --rpc-url $BASE_RPC --private-key $MATCHER_KEY
cast send 0xc4152c73824d85146B0f85a0b77E911D4769d936 \
  "supply(uint256)" 500000000000 \
  --rpc-url $BASE_RPC --private-key $MATCHER_KEY

cast send 0xE7e7008D71387a79Bf57F1E5Ab75534d4b3DA34A "poke()" --rpc-url $BASE_RPC
```

---

## Done when

Landing USDC **+ $500,000**.
