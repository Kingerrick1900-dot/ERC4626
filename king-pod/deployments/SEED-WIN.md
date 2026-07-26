# Win the Seed — Nation Seed Cannon

Ambition over dust. One contract. Outsiders fund the Kingdom in one tx.

## Live target

| | |
|--|--|
| **Nation Seed** | *(set after deploy)* |
| Completer | `0x12514e1f999131eA78D402a7258b67A65F9342Ff` |
| yELE vault | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| maxAsk | **$700,000** |
| Default split | **70%** → ZK completer → Landing · **30%** → yELE (King shares) |

## Matcher / desk — one move

```bash
# 1) Approve Nation Seed for ASK
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" $NATION_SEED $ASK \
  --rpc-url "$RPC_URL" --private-key "$MATCHER_KEY"

# 2a) Split seed (ops + vault)
cast send $NATION_SEED "seed(uint256)" $ASK \
  --rpc-url "$RPC_URL" --private-key "$MATCHER_KEY"

# 2b) Or 100% ops → Landing
cast send $NATION_SEED "seedOps(uint256)" $ASK \
  --rpc-url "$RPC_URL" --private-key "$MATCHER_KEY"

# 2c) Or 100% vault TVL (curator fee base)
cast send $NATION_SEED "seedVault(uint256)" $ASK \
  --rpc-url "$RPC_URL" --private-key "$MATCHER_KEY"
```

Suggested first ASK: **$50,000 – $100,000** then scale to **$700,000**.

## Deploy (King)

```bash
KING_GO=1 FIRE_NATION_SEED=1 \
forge script script/FireNationSeed.s.sol:FireNationSeed \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Optional prove pipe with dust (only if King orders): `SELF_SEED_USDC=1000000` ($1).

## Pitch (one breath)

King Errick is ZK-proven at $1M. Send USDC to the Nation Seed cannon — it lands ops on Landing and grows the curated yELE book under the King’s $10 oracle rail. Max draw **$700k**. One approve. One call. Fund the nation.
