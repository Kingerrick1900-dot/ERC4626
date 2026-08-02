# Exit ladder — DeepSeek loop, engineered

## Correction (one line)

**Headroom ≠ idle.** Morpho `borrow` pulls cash sitting in the market (`totalSupplyAssets − totalBorrowAssets`). LLTV room only caps *how much* you may borrow once idle exists.

Live ELE/USDC: idle ≈ **$1**. Headroom can be tens of millions and Step 1 still reverts / returns 0.

## DeepSeek sequence → code

| Step | DeepSeek | `CrownExitLadder` |
|--|--|--|
| 1 | Borrow USDC from ELE market | Needs **idle ≥ seed** (not headroom) |
| 2 | Supply that USDC to yELE | `yELE.deposit` (asset = USDC) |
| 3 | Extractor reallocates into ELE/USDC | `yELE.reallocate` WETH→ELE |
| 4 | Borrow again → wallet/Landing | Second `borrow` → Landing |

Net (when Step 1 has real idle): Landing **+seed**, debt **+2·seed**, ELE stays collateral.

Contract: `king-pod/src/CrownExitLadder.sol`  
Fire: `king-pod/script/FireExitLadder.s.sol`

## Exits armed

### A — `drawIdle` (live anytime)
Borrow liquid idle → Landing. With ~$1 idle this is dust / zero (no fake borrow).

```bash
KING_GO=1 FIRE_EXIT=1 MODE=idle \
forge script script/FireExitLadder.s.sol:FireExitLadder \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

### B — `leverageLoop` (DeepSeek math)
Requires: idle ≥ `ASK_USDC`, yELE WETH market enabled, ladder set as allocator + Morpho auth.

```bash
KING_GO=1 FIRE_EXIT=1 MODE=loop ASK_USDC=700000000000 \
forge script script/FireExitLadder.s.sol:FireExitLadder \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

### C — Disk fill (first idle seed without a whale)
After WETH `acceptCap` unlock: put USDC on hot → deposit yELE → `curatorDiskFill` → Landing +ask.  
See `DISK-FILL-700K.md` / `FireDiskFill700k`.

First seed sources (any one): whale idle on Morpho, PA maxIn from a liquid vault, or disk-fill USDC on hot.

## Fork proof

```text
[PASS] test_drawIdle_without_liquidity_is_zero  — got 0 (no headroom fiction)
[PASS] test_leverageLoop_with_seeded_idle       — landed 699999999998
```

Whale supplies $700k idle on fork → DeepSeek loop prints ~$700k to Landing.
