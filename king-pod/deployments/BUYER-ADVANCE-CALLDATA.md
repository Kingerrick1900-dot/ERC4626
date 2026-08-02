# Buyer Advance — Exact Call (Against Verified ZK Proof)

**Buyer advances USDC against verified ZK proof.** Not a mock. Not King self-fund.

## Preflight (anyone)

```bash
cast call 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205 \
  "isProven(address)(bool)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url $BASE_RPC
# must be true
```

## Contracts

| | |
|--|--|
| CrownZkAdvance | `0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Landing (USDC destination) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| kUSD to buyer | `0x0FEA62084A024544891f03035E85401C2C886c1b` |

## \$500k — exact calldata

```
approve:  0x095ea7b3000000000000000000000000d36ad3bf4e4a619f5b8f8c22dda90e313f23035b000000000000000000000000000000000000000000000000000000746a528800
advance:  0x71d6ddd6000000000000000000000000000000000000000000000000000000746a528800
```

## \$700k — exact calldata (full stock ~699994e6 max)

```
approve:  0x095ea7b3000000000000000000000000d36ad3bf4e4a619f5b8f8c22dda90e313f23035b000000000000000000000000000000000000000000000000000000a2fb405800
advance:  0x71d6ddd6000000000000000000000000000000000000000000000000000000a2fb405800
```
Note: stock is 699994e6 — use that exact amt for full clear, or 500k above.

## Cast (real buyer / King-controlled funded wallet)

```bash
ADV=0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
AMT=500000000000

# 1) approve
cast send $USDC $AMT_APPROVE_CALLDATA --private-key $BUYER_KEY --rpc-url $BASE_RPC
# or:
cast send $USDC "approve(address,uint256)" $ADV $AMT --private-key $BUYER_KEY --rpc-url $BASE_RPC

# 2) advance — KING GO required before scribe broadcasts
cast send $ADV "advance(uint256)" $AMT --private-key $BUYER_KEY --rpc-url $BASE_RPC
# → REPORT HASH IMMEDIATELY
```

Raw:
```bash
cast send $USDC 0x095ea7b3000000000000000000000000d36ad3bf4e4a619f5b8f8c22dda90e313f23035b000000000000000000000000000000000000000000000000000000746a528800 \
  --private-key $BUYER_KEY --rpc-url $BASE_RPC
cast send $ADV 0x71d6ddd6000000000000000000000000000000000000000000000000000000746a528800 \
  --private-key $BUYER_KEY --rpc-url $BASE_RPC
```

## Sequence

1. Calldata prepared (**this doc**)  
2. **King GO**  
3. Real buyer (or King-controlled wallet with real USDC) broadcasts  
4. Confirm hash · Landing USDC · buyer kUSD  
5. Route Landing → bills / KingVault  

**Scribe:** no live fire until KING GO. Then report hash immediately.
