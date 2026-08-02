# Atomic Cold-or-Revert — LIVE

**Rule:** funds hit Landing (cold) in **one tx**, or the loan **fully reverts**. No stick on hot.

| Item | Address |
|------|---------|
| **CrownZkCredit V2** (use this) | `0x01814e15cF01DEcdC7239b739177C36acaBaBA54` |
| Gate (unchanged) | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| Cold / Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| LLTV | **100%** of attested \$700k |
| `borrowTo(cold, amt)` | atomic · `ColdMiss` reverts whole tx |

Legacy credit `0xeAE626…D392` — superseded (no `borrowTo`).

### Counterparty
`supply(USDC)` → **V2** `0x01814e15…BaBA54`

### King draw (when funded)
```bash
KING_OK=1 FIRE_ATOMIC_COLD=1 DEPLOY=0 DRAW=1 CREDIT=0x01814e15cF01DEcdC7239b739177C36acaBaBA54 \
  BORROW_AMT=700000000000 \
  forge script script/FireZkAtomicCold.s.sol:FireZkAtomicCold --rpc-url $BASE_RPC --broadcast
```
