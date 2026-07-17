# Plan B — Execution (no buyers, no waiting)

## Objective
Pull stranded kingdom capital out of V1, land USDC on vault, Morpho debt 0.

## Why this plan
Buyer rail is dead. Dust loop is dead. ~$170k LP is already inside V1 market `0x50A61cA6b06563f1A44f7F2186A325b5301e2578` with no `releaseCollateral`. That capital is ours to extract by engineering — not by waiting.

## Execution order

### 1. V1 LP rescue contract
- Deploy `KingV1LpRescue` that King (owner) controls.
- Target: pull LP / underlying out of V1 market + pair without relying on missing `releaseCollateral`.
- Methods to attempt in order (same owner key):
  1. Owner privilege paths on V1 market / pair / related vault (rescue, sweep, skim, recover).
  2. If market holds LP for King as collateral accounting only — migrate accounting via new market adapter that King authorizes, or burn/redeem path if any residual admin exists.
  3. If immutable brick: deploy replacement receiver + prove exact trapped balances on BaseScan for King decision (fork vs abandon size).

### 2. Convert rescued assets → hard USDC
- Burn pair LP → RSS + sUSDC/USDC.
- Redeem any sUSDC only if `totalAssets > 0`; otherwise keep RSS, USDC cash only counts.

### 3. Load rail + fire (no recycle)
- USDC → desk `seed`.
- Closer `0x39D8…1a41` already `railBps = 0`.
- `eliteFlashClose` → 100% to vault `0xA1aF…832a`, debt 0.

### 4. Stack
- Repeat step 3 on every USDC recovered from rescue tranches.
- Stop agent spend between rescue builds — no empty-rail watcher.

## Kill list
- Wait for buyers / sale fills
- Auto-rail 100% recycle
- Flash-open self-lend as “vault fill”
- Morpho curator hopium

## Done when
Vault USDC up by rescued cash; King Morpho borrow shares = 0; V1 trapped LP reduced or fully cleared.
