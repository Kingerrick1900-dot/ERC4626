# Missing piece — Landing USDC exit facility

**Problem:** BFB/#5 needs a USDC venue. Aero RSS/USDC ≈ **$0.67**. No UniV3 RSS pools.

**Build:** `CrownLandingUsdcFacility` — fillable rails. King already holds the non-USDC legs (eUSD + free RSS). King owns MultiPSM + eUSD.

| Rail | Funder posts | King posts | Fork Landing Δ |
|--|--|--|--|
| **A OTC eUSD** | USDC via `fundOtc` | eUSD (`settleOtcEusd`) | **+$700,000** PASS |
| **B RSS desk** | USDC via `fundDesk` | lock RSS, `desk.draw` | **+$700,000** PASS |
| **C PSM buffer** | USDC via `fundPsmBuffer` | `pull` + `psm.seed` (onlyOwner) | reserve +$700k; redeem ABI still Dry — use A/B to settle |

## Fork

```bash
forge test --match-contract LandingUsdcFacilityFork -vv --fork-url https://mainnet.base.org
```

## Deploy

```bash
DEPLOY_DESK=1 forge script script/DeployLandingUsdcFacility.s.sol:DeployLandingUsdcFacility \
  --rpc-url https://mainnet.base.org --broadcast -vvvv
```

## Fill → settle (name a funder)

**Rail A (fastest — Landing already has ~$700k eUSD)**
```text
funder: facility.fundOtc(700_000e6)
king:   move eUSD Landing→hot, approve, settleOtcEusd(700_000e6, 700_000e18)
```

**Rail B (loan, don’t sell RSS)**
```text
funder: facility.fundDesk(DESK, 700_000e6)
king:   RSS.approve(DESK); desk.draw(≥778e18, 700_000e6, Landing)
```

## Scoreboard after settle

`USDC.balanceOf(Landing) >= 700_000e6`

Missing piece is engineered: **on-chain USDC intake + settle to Landing**. Next input is the funder’s USDC line (OTC buyer or desk lender).
