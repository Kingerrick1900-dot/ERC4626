# Loan Completion — LIVE

**King-side complete.** Matcher finishes in **one transaction**.

| Piece | Address |
|--|--|
| Completer | **`0x8117ec3F32CdB12DB1A6Eb8eee280B75d1C4e5C7`** |
| Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| Auto-draw (alt) | `0xB6481E2ca95c14BC47B29b60fec6eF7e4A398a23` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Proof | ZK `isProven` **$1M** · maxAsk **$700k** · loan ask **$500k** |

## Matcher — loan complete (atomic)

```bash
# 1) approve completer
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" \
  0x8117ec3F32CdB12DB1A6Eb8eee280B75d1C4e5C7 \
  500000000000 \
  --rpc-url $BASE_RPC --private-key $MATCHER_KEY

# 2) one tx: supply credit + draw Landing
cast send 0x8117ec3F32CdB12DB1A6Eb8eee280B75d1C4e5C7 \
  "complete(uint256)" \
  500000000000 \
  --rpc-url $BASE_RPC --private-key $MATCHER_KEY
```

`complete(500k)` = prove check → pull USDC → `credit.supply` → `credit.borrow` → **Landing**.

JSON: `zk-liquidity-match.json`  
Proof sheet: `PROVE-LIQUIDITY-MATCH.md`
