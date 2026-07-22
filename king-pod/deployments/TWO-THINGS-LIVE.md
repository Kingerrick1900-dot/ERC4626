# Two Things — LIVE (bills are real)

Fees & yield. Governance. Then RSS leverage → Landing.

## 1) Fees & Yield — LIVE

| | |
|--|--|
| Vault | yRSS `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Fee | **10%** (`1e17` WAD) |
| Recipient | **Landing** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Source | Borrow interest on markets King allocates (RSS/USDC primary) |

Every USDC borrow against RSS accrues fee to **cold**. Not a promise — on-chain.

## 2) Governance — LIVE

| Seat | Who |
|------|-----|
| yRSS owner | King hot |
| yRSS curator | King hot |
| yRSS allocator | King hot |
| Vault V2 owner | Landing (treasury supremacy) |
| Vault V2 curator | King hot |
| Vault V2 allocators | hot + landing |

No DAO. No committee. Sovereign command.

## Leverage → Landing (the draw)

| Step | Action |
|------|--------|
| 1 | Kingdom balance sheet USDC → yRSS (King-controlled fill — not stranger hope) |
| 2 | King allocates into RSS/USDC Morpho market |
| 3 | Post RSS collateral |
| 4 | `borrow` USDC **receiver = Landing** |
| 5 | Landing miss → full revert |

Fire:

```bash
# Confirm seats + fee (no draw)
KING_OK=1 FIRE_KING_LEVERAGE=1 forge script script/FireKingLeverage.s.sol \
  --rpc-url $BASE_RPC --broadcast --chain 8453

# Draw when market idle ≥ size
KING_OK=1 KING_GO=1 FIRE_KING_LEVERAGE=1 DRAW=1 USDC_AMT=500000000000 \
  RSS_COLL=1000000000000000000000000 \
  forge script script/FireKingLeverage.s.sol --rpc-url $BASE_RPC --broadcast --chain 8453
```

## Also live

| | |
|--|--|
| Vault V2 | `0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9` |
| RSS market | `0x40ac09f3…b794` · Fixed $1 oracle · owner burned |
| Collateral machine | `0x27bF9A70…800c` · cold-or-revert |

**Outcome:** yield to cold · keys are King’s · $700k is borrow against RSS once vault USDC sits in the market King allocates.
