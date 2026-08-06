# $200M RSS/$1200 self-seed + self-del — LIVE

## Live (Base)
| Field | Value |
|--|--|
| Market | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| Borrow | **$200,000,000** exactly (`200000000000000` raw) |
| Supply | $200,000,000 + 1 wei dust |
| Hot coll | **220,000 RSS** on Morpho (HOT-owned) |
| Seed tx | `0xbe63e15e171af68b52fc3233f72fb407b91a7cbdeb1f07e10d6253469c16664b` |
| Helpers | auth **revoked** (position on HOT only) |

## Rules
- Position on **HOT** Morpho — not stuck in a helper.
- Helper auth revoked after each fire (seed helpers auth = false).
- Matched book. Hold until King engineers ops value.

## Self-liq / self-del — SET
| Check | Status |
|--|--|
| Position owner | **HOT** (King controls repay + withdrawCollateral) |
| Seed helper auth | **revoked** |
| Unwind script | `FireSelfDel1200` (flash → repay → RSS to HOT → withdraw supply → repay flash) |
| Fork proof @ live $200M | **PASS** (`test/SelfDel200mFork.t.sol`) |
| Live book left intact | yes — fork only; not fired on mainnet |

```bash
# Prove anytime
forge test --match-contract SelfDel200mFork -vv

# Fire live self-del (King GO only)
FIRE_SELF_DEL_1200=1 forge script script/FireSelfDel1200.s.sol:FireSelfDel1200 \
  --rpc-url $BASE_RPC_URL --broadcast --slow -vvv
```

