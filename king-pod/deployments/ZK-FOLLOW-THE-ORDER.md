# ZK Advance — Follow the Order

**ZK = counterparty layer.** Not King self-fund. Buyer advances USDC against `isProven(king)`.

## Order

1. Buyer holds ≥ \$500k USDC on Base  
2. Verify shield: `isProven(0x6708…a7d1) == true`  
3. `approve` USDC → `CrownZkAdvance`  
4. `advance(500000e6)` (or larger ≤ kUSD stock)  
5. On success: **USDC → Landing** · **kUSD → buyer**  
6. Report tx hash · route bills from Landing  

## Live door

| | |
|--|--|
| CrownZkAdvance | `0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B` |
| Gate | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| kUSD stock | ~699,994 |

## Buyer cast (Base)

```bash
ADV=0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
AMT=500000000000   # $500k — scale up as ordered

cast send $USDC "approve(address,uint256)" $ADV $AMT --private-key $BUYER_KEY --rpc-url $BASE_RPC
cast send $ADV "advance(uint256)" $AMT --private-key $BUYER_KEY --rpc-url $BASE_RPC
# → report hash immediately
```

Or King GO with `BUYER_KEY` set:

```bash
KING_OK=1 KING_GO=1 FIRE_ZK_TEST=1 ADVANCE_USDC=500000000000 BUYER_KEY=0x... \
  forge script script/FireZkAdvanceTest.s.sol:FireZkAdvanceTest --rpc-url $BASE_RPC --broadcast
```

**Live broadcast:** on **KING GO** + funded buyer. Fork ordered test proves the path.
EOF
