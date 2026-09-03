# PRIME-BROKERAGE-1B-50PCT-SAFE — FINAL TO SHIP

**PR:** #129 · **Chain:** Base · **Status:** implement + forge green; mainnet fire needs `KING_GO=1`

---

## King plan (100 words)

Mint **1B eUSD — KEEP. No more mint.** Split zero-idle: **400M** LitePSM door (0.05%), **300M** 7683 fill (10%/7%/5% stagger; first $2M USDC → $2.2M eUSD), **200M** BoundLanding credit base, **100M** promo (≈$1M subsidy on $10M@10%). Paper mark **$22M**; **LLTV 50%** → **$11M debt max**. Sell **10M eUSD @10%** → **~$9M USDC idle, no debt**. One-shot `kingEmergencyDraw(2e6)` (bypasses arm, not physics — needs cash). Arm on idle proof → draw rest → **debt ≤ $11M**. Liquid now: **~$9M sale + ≤$11M borrow ≈ $20M**. Early vault **5%** on $10M ($550k/yr vs ~$1.9M fees). Cap + 14d lock. Solvent even if eUSD=$0.80.

---

## Split — Zero Idle (1B total)

| Slice | Amt | Destination |
|-------|-----|-------------|
| LitePSM | 400M | `CrownLitePsm` — Base USDC in, 0.05% fee |
| 7683 Fill | 300M | `CrownPrime7683Fill` — 10% / 7% / 5% stagger |
| Credit base | 200M | `CrownBoundLandingCollateral` + router |
| Promo | 100M | Discount subsidy; ~99M left after $10M@10% |

## Safe params

| Param | Value |
|-------|-------|
| `PAPER_USD6` | 22_000_000e6 |
| `floatUsd8` (paper) | 2.2e6 ($0.022 / eUSD) |
| `lltv` | 50e16 (50%) |
| Max debt | 11_000_000e6 |
| `EMERGENCY_CAP` | 2_000_000e6 (one-shot) |
| Early APR | 5% · cap $10M USDC · 14d lock |

**Why 50%:** $22M paper + $9M idle ≈ $31M backing on $11M debt ≈ **281%**. At eUSD $0.80 still solvent. No liq path on BoundLanding.

## Draw NOW order

1. Mint 1B eUSD (KEEP)
2. Seed LitePSM 400M
3. List ~10M eUSD @ 10% via 7683 → **~$9M USDC idle, no debt**
4. `kingEmergencyDraw(2_000_000e6)` — one-time, bypasses `armed`, still needs cash+capacity
5. `setArmed(true)` with idle proof → draw remaining ≤9M → **total debt ≤ $11M**

**Liquid:** ~$9M sale + ≤$11M borrow ≈ **$20M**

## Forge — must pass 6/6

```bash
forge test --match-contract PrimeBrokerage1B50SafeTest -vv
```

- `test_kingDrawMax_50`
- `test_backing_281pct`
- `test_emergencyCap_2M`
- `test_noDrawOver_11M`
- `test_idleBeforeArm`
- `test_paperPrice_22M`

## Mainnet

```bash
KING_GO=1 FIRE_PRIME=1 PRIVATE_KEY=0x… \
  forge script script/FirePrimeBrokerage.s.sol:FirePrimeBrokerage \
  --rpc-url $BASE_RPC_URL --broadcast -vvv
```

Router deploys **disarmed**. King seeds, sells, emergency-draws, then arms.
