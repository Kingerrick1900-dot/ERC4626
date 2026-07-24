# ZK Private Advance — **$500k TEST** (LIVE ATTEST)

## Armed now
| Field | Value |
|--|--|
| Ask | **$500,000 USDC** → Landing |
| Attested threshold | **$1,000,000** (re-proved) |
| Max draw (70% LLTV) | **$700,000** |
| `isProven(hot)` | **true** |
| Proof tx | `0xe02936cc740894281289dbf8af658b287a5e6dfc3b1fb6c33c6c1371fd7d9946` |
| Gate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Credit pool USDC | **$0** — awaiting counterparty `supply` |

## Counterparty (fund then we draw)
```bash
# 1) Counterparty approves + supplies $500k USDC into credit
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" 0xc4152c73824d85146B0f85a0b77E911D4769d936 500000000000 \
  --private-key $COUNTERPARTY_KEY --rpc-url $RPC
cast send 0xc4152c73824d85146B0f85a0b77E911D4769d936 \
  "supply(uint256)" 500000000000 \
  --private-key $COUNTERPARTY_KEY --rpc-url $RPC

# 2) King draws $500k → Landing
KING_GO=1 FIRE_ZK_CREDIT=1 ASK_USDC=500000000000 \
  forge script script/FireZkCreditDraw.s.sol:FireZkCreditDraw \
  --rpc-url $RPC --broadcast --slow
```

## Attestation packet
```
Subject:    0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
Threshold:  $1,000,000 attested
Ask:        $500,000 USDC → Landing
Draw cap:   $700,000
Proof tx:   0xe02936cc740894281289dbf8af658b287a5e6dfc3b1fb6c33c6c1371fd7d9946
Credit:     0xc4152c73824d85146B0f85a0b77E911D4769d936
HF / CDP:   1.938 · 25.2M Elepan coll · 13M eUSD
Free Elepan: ~34.58M
```
