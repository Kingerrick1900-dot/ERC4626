# Verdict — $300 dust debt (scribe error, fix ready)

## What happened

King arrived **debt-free**. Three loan fires ran. The last “debt-free” path (`CrownChunkFreeRss`) **intentionally stopped at ~$300**:

```solidity
uint256 public constant DUST_DEBT = 300e6; // leave ~$300 debt (avoids rounding Short)
```

That was **scribe design**, not “couldn’t find funds.” Docs wrongly marked Step A “DONE (dust only left).” King never asked for interest-bearing dust.

## On-chain now (Base)

| Field | Value |
|-------|--------|
| Morpho debt | **~$300.05** (sole borrower) |
| Coll posted | **500 RSS** (cushion for dust) |
| Hot USDC | **~$1** |
| yRSS (King) | **~$299** locked until debt repaid |
| Landing USDC | **~$5.57** (separate; not needed if fix is exact) |

Pre-tx `maxWithdraw` on yRSS shows **~$1** because util ≈ 100% — **misleading**. Inside one tx, repay unlocks ~$299 yRSS to cover the flash.

## Fix — `CrownZeroMorpho.zeroBooks()`

One atomic tx:

1. Morpho flash **exact** pro-rata debt (no +$10 pad — that pad **guaranteed Short()** on fork)
2. Repay **all** borrow shares → debt **0**
3. Withdraw **all** collateral → **+500 RSS** to hot
4. yRSS withdraw + King's **direct Morpho supply (~$1 seed)** + hot USDC → repay flash
5. Redeem leftover yRSS dust to hot

**Fork proof:** `forge test --match-test test_zero_morpho --fork-url https://mainnet.base.org` → `bor=0`, `coll=0`, **+500 RSS** to hot.

Prior live `ClearMorphoHotOnly` failed: wrong market tuple + `$10` flash pad. Fixed in `CrownZeroMorpho`.

## Fire (King only)

```bash
cd king-pod
KING_OK=1 FIRE_ZERO=1 forge script script/FireZeroMorphoDebt.s.sol \
  --rpc-url https://mainnet.base.org --broadcast --slow
```

Dry-run first (`FIRE_ZERO=0`). Requires hot gas + yRSS approve (script sets).

## After zero

- **No Morpho interest** on Kingdom RSS book
- **+500 RSS** back on hot (plus ~$1 USDC dust)
- yRSS mostly redeemed — re-arm when Phase 1 whale depth exists

**Not** Phase 1 $500k Landing — this only closes the scribe wound.
