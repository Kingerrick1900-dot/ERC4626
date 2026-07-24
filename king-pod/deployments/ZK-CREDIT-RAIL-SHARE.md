# Grey Area #1 — ZK Credit Rail (share this)

**Status live:** Hot is proven. Credit contract aims USDC at Landing.  
**Ask:** Counterparty supplies USDC → King draws → Landing.

---

## One-paragraph pitch

King Errick’s hot wallet is ZK-attested at **$1,000,000**. Kingdom credit `CrownZkElepanCredit` pays draws to Landing at **70% LTV**. Supply **$500,000 USDC** (or any size ≤ pool) into the credit contract; King draws up to **min(pool, $700,000)** to Landing the same day. Proof is on-chain — no custodial escrow theater.

---

## Addresses (Base)

| Piece | Address |
|--|--|
| Hot (proven borrower) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing (receives USDC) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| ZK Gate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| ZK Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |

## Live checks (now)

| Check | Value |
|--|--|
| `isProven(hot)` | **true** |
| Attested value | **$1,000,000** (1e12 raw 6dp) |
| Gate minThreshold | **$700,000** |
| Credit LLTV | **70%** |
| Max draw when funded | **$700,000** (= 70% × $1M) |
| Suggested first ask | **$490,000 – $500,000** |
| Credit USDC balance | $0 until supplier `supply`s |
| `maxBorrow(hot)` | 0 until pool has USDC |
| Draw destination | Landing (immutable on credit) |

---

## Counterparty steps (2 txs)

```bash
# 1) Approve + supply USDC into credit (anyone)
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" \
  0xc4152c73824d85146B0f85a0b77E911D4769d936 \
  500000000000 \
  --rpc-url $BASE_RPC --private-key $SUPPLIER_KEY

cast send 0xc4152c73824d85146B0f85a0b77E911D4769d936 \
  "supply(uint256)" \
  500000000000 \
  --rpc-url $BASE_RPC --private-key $SUPPLIER_KEY
```

## King draw (after supply)

```bash
cd king-pod
KING_GO=1 FIRE_ZK_CREDIT=1 ASK_USDC=500000000000 \
  forge script script/FireZkCreditDraw.s.sol:FireZkCreditDraw \
  --rpc-url $BASE_RPC --broadcast --slow
# uses borrow(uint256) / borrowTo — USDC lands on Landing
```

---

## Collateral / fortress context (why the proof clears)

- Free + posted Elepan surface after Move 1: hot **~56M** Elepan liquid  
- Morpho: **~$14M** borrow still open · **~20M** Elepan still posted  
- CDP: **~24M** Elepan posted · **~14.6M eUSD** on Landing · HF **~1.64**  
- yELEPAN-USDC vault: **~$14M** TVL (King curator)

Hand this sheet to 1–2 trusted counterparties. First `supply` unlocks the draw.
