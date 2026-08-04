# $200M RSS/$1200 self-seed + self-del

## Rules
- Position on **HOT** Morpho — not stuck in a helper.
- Helper auth revoked after each fire.
- Matched book (supply ≈ borrow). Hold until King engineers ops value.
- Self-del anytime: `FireSelfDel1200` (reverse flash → RSS back to HOT).

## Fire seed
```bash
FIRE_SEED_1200=1 forge script script/FireFlashSeed1200.s.sol:FireFlashSeed1200 \
  --rpc-url $BASE_RPC_URL --broadcast --slow -vvv
```

## Self-del (King anytime)
```bash
FIRE_SELF_DEL_1200=1 forge script script/FireSelfDel1200.s.sol:FireSelfDel1200 \
  --rpc-url $BASE_RPC_URL --broadcast --slow -vvv
```

## Sizing
| Field | Value |
|--|--|
| Seed | $200,000,000 USDC |
| Coll | 220,000 RSS (@ $1200, 77% LLTV) |
| Market | `0x41c08085…bf7d88` |
