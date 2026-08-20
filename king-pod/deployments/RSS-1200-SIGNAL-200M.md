# RSS/$1200 $200M signal — self-del set, headroom on RSS

**Not idle. Not payroll.** Re-claim the matched Morpho book King already ran (`0xbe63e15e…`).

Position on **HOT**. Chassis stays Morpho-authorized so unwind is one call.

## Size (scaled back — do not post the stack)

| Knob | Old live fire | This fire |
|--|--|--|
| Ask / book | **$200,000,000** | **$200,000,000** (same signal) |
| RSS coll | 220,000 (HF ~1.32, razor vs 77% LLTV) | **250,000** (HF **1.50**) |
| RSS left liquid | rest of hot | **≥ 1,000,000** required; ~15M − 250k stays free |
| Coll cap | none | **500,000 RSS max** (cannot dump inventory) |

Min coll vs $200M @ $1200 / 77% LLTV ≈ **216,451 RSS**. 250k is headroom, not the whole bag.

## Unwind (set before seed)

Same contract: `unwind()` = `selfDel()` = `selfLiq()`.

```
flash → repay HOT debt → withdrawCollateral to HOT → withdraw supply → repay flash
```

Fork proves seed **and** full clear (shares/coll = 0, RSS back).

## Fire (King GO)

Prep (deploy + auth, no seed):

```bash
cd king-pod
KING_OK=1 forge script script/FireRss1200Signal.s.sol:FireRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

Seed $200M:

```bash
KING_OK=1 FIRE_SIGNAL=1 forge script script/FireRss1200Signal.s.sol:FireRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

Self-del / self-liq (any time):

```bash
KING_OK=1 FIRE_UNWIND=1 SIGNAL=<CrownRss1200Signal> \
  forge script script/UnwindRss1200Signal.s.sol:UnwindRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

`SIGNAL` unset still works — deploys a fresh unwind chassis (original `FireSelfDel1200` path).

## Fork

```bash
forge test --match-contract Rss1200SignalForkTest -vvv --fork-url https://mainnet.base.org
```

## Market

```
RSS/$1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
ORACLE    = $1200 (1.2e27)
LLTV      = 77%
```
