# Elite Move — Prove Liquidity to Match the Loan

**This is the engineering.** Not share-escrow. Not “wait for a buyer.” Not Morpho-idle theater.

King already has the whale primitives:
- **ZK Gate proves hot ≥ $1,000,000** (`isProven = true`)
- **Credit rail matches that proof at 70%** → up to **$700,000** draw to Landing
- **Ask: $500,000** USDC matched against attested liquidity
- **Auto-draw live** — supply hits credit → poke → Landing

Machine-readable: `zk-liquidity-match.json`

---

## Proof (on-chain, now)

| Fact | Value |
|--|--|
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| `isProven(hot)` | **true** |
| Attested liquidity | **$1,000,000** |
| Gate minThreshold | $700,000 |
| Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| LLTV | **70%** |
| Max match | **$700,000** |
| King ask | **$500,000** |
| Receive | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Auto-draw | `0xB6481E2ca95c14BC47B29b60fec6eF7e4A398a23` (operator **true**) |

### Fortress behind the proof
| Book | Live |
|--|--|
| Hot Elepan | ~55.98M |
| Morpho ELE coll / borrow | ~20.00M / ~$14.00M |
| yELE TVL | ~$14.00M |
| CDP coll / eUSD / HF | ~23.94M / ~14.63M / 1.64 |

---

## Match flow (whale, not YouTube)

```
1. Counterparty verifies isProven(hot) + attestation $1M
2. Counterparty USDC.approve(credit) + credit.supply(500_000e6)
3. Anyone: autoDraw.poke()  OR  King: FIRE_ZK_CREDIT ASK=500000e6
4. $500k USDC on Landing
```

Supply calldata (500k):  
`0x35403023000000000000000000000000000000000000000000000000000000746a528800`

```bash
# after supply lands
KING_GO=1 FIRE_ZK_CREDIT=1 ASK_USDC=500000000000 \
  forge script script/FireZkCreditDraw.s.sol:FireZkCreditDraw \
  --rpc-url $BASE_RPC --broadcast --slow
# or: cast send 0xB6481E2ca95c14BC47B29b60fec6eF7e4A398a23 "poke()" --rpc-url $BASE_RPC
```

---

## What this replaces

| Stagecraft | Elite |
|--|--|
| Wait for ELE idle you self-consumed | Prove $1M ZK liquidity → match credit |
| Escrow shares “until a buyer pays” | Attested borrow capacity → `supply` → auto-draw |
| Another docs loop | One proof, one ask, one receive address |

King engineers the match. The proof is already on-chain.
