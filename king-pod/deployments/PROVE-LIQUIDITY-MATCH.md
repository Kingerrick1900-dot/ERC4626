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
| Completer | **`0x12514e1f999131eA78D402a7258b67A65F9342Ff`** (operator **true**) |
| Auto-draw | `0xE7e7008D71387a79Bf57F1E5Ab75534d4b3DA34A` (operator **true**) |

### Fortress behind the proof
| Book | Live |
|--|--|
| Hot Elepan | ~55.98M |
| Morpho ELE coll / borrow | ~20.00M / ~$14.00M |
| yELE TVL | ~$14.00M |
| CDP coll / eUSD / HF | ~23.94M / ~14.63M / 1.64 |

---

## Match flow — loan complete

**Primary (one tx):** completer `0x1251…42Ff`

```
1. Verify isProven(hot) + attestation $1M
2. USDC.approve(completer) + complete(500_000e6)
3. $500k USDC on Landing
```

```bash
KING_GO=1 FIRE_LOAN_MATCH=1 ASK_USDC=500000000000 \
  MATCHER_KEY=$MATCHER_KEY \
  forge script script/FireMatcherComplete.s.sol:FireMatcherComplete \
  --rpc-url $BASE_RPC --broadcast --slow
```

Full sheet: `LOAN-COMPLETE-LIVE.md`

**Alt:** `credit.supply(500k)` → `autoDraw.poke()` or `FIRE_ZK_CREDIT`

---

## What this replaces

| Stagecraft | Elite |
|--|--|
| Wait for ELE idle you self-consumed | Prove $1M ZK liquidity → match credit |
| Escrow shares “until a buyer pays” | Attested borrow capacity → `supply` → auto-draw |
| Another docs loop | One proof, one ask, one receive address |

King engineers the match. The proof is already on-chain.
