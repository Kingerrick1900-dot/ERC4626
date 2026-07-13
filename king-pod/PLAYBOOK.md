# King Errick — Five-Phase Sovereign Desk Playbook

Scribe executes. King commands. No unrepayable flashes. No exploit bait.

## End state (what “legendary” actually means)

| Capability | Status | Honesty |
|---|---|---|
| Sovereign Morpho RSS/USDC market (oracle, IRM, LLTV) | **LIVE** | Full control of oracle price + market params |
| Self-reinforcing lend loop (supply↔borrow) | **LIVE** | Deepens Morpho book / HF position — **not** free spendable USDC |
| Self-deleverage safeguard | **WIRED** | Morpho 0-fee flash → repay → withdraw supply |
| VIP Rescue Desk (opt-in fee) | **LIVE** on fleet | Recurring revenue from whales who enroll |
| Quiet scaler | **WIRED** | Env-gated incremental loops; no public Morpho listing push |
| Telegram Scribe control | **LIVE** | `morpho status` / floors / deleverage |

## Phase 1 — Sovereign market
- Deploy `MorphoFixedOracle` at Crown price **$0.05 / RSS** (`5e22` Morpho scale).
- Deploy `MorphoKingDesk`; `createMarket` with AdaptiveCurveIRM + **77% LLTV**.
- Addresses: see `deployments/morpho-desk.json`.

## Phase 2 — Self-lend open (buffered)
- Authorize desk on Morpho; approve RSS.
- `openSelfLend(20M RSS, $500k USDC)` → flash → supply → collateral → borrow → repay.
- Target HF ≈ **1.54** (well above 1.05 floor). Keep ~1M RSS liquid for gas/ops/scale.

## Phase 3 — Guardian (auto flash safeguard)
- PM2 `morpho-guardian` polls desk `healthFactor(king)`.
- If HF < floor → compute repay to reach `hfTarget` → `selfDeleverage(repay)`.
- Default floor **1.05**, target **1.15** (King can change via Telegram / `setFloors`).

## Phase 4 — VIP Rescue Desk
- Opt-in enrollment in `rescue_clients` (fee default **7%**).
- `kesov-kingdom` `runRescueMonitorLoop` alerts on HF warn/critical; excludes VIPs from hostile queue.
- Revenue = disclosed rescue fee on executed saves — not Morpho loop interest.

## Phase 5 — Quiet scaler + Telegram
- Scaler only runs when `QUIET_SCALE_ENABLED=1` and HF ≥ scale-min; small RSS increments only.
- Never markets the Morpho market publicly; deepen via King collateral only.
- Telegram (authorized King chat):
  - `morpho status` — market, supply/borrow, HF, floors, liquid RSS
  - `morpho floors 1.05 1.15` — set desk floors on-chain
  - `morpho deleverage` or `morpho deleverage 50000` — manual safeguard
  - `pod status` — legacy King Pod Option A

## Allowed
- Self-lend loops with HF ≥ floor
- Crown oracle ($0.05) updates by owner
- Self-deleverage; VIP rescue opt-in
- Quiet scale under caps

## Banned
- Unrepayable flashes / cash-LP → borrow 70% → repay 100% fantasies
- Oracle spam, outsider NAV drains, wrap-rate exploits
- Fake TVL bait-and-rug / public lure campaigns

## Hard truths (Scribe will not lie)
1. Circular Morpho debt is **sovereignty + TVL optics + RF capacity**, not treasury cash.
2. Spendable USDC still requires real inflows (rescue fees, idle deposits, or assets sold).
3. Legendary = control + survival + fee desk — not magic leverage.


## Proceeded ops (2026-07-13)
- Manual scale: +500k RSS / +$12.5k circular USDC → book ≈ **$512.5k**, HF ≈ **1.54**, ~500k RSS liquid.
- Quiet scaler: **ENABLED**, liquid reserve 500k (armed for future RSS).
- VIP Telegram: `rescue status` · `rescue enroll 0x…` · `rescue remove 0x…`
- Hostile + VIP systems both live; king-liq on hybrid RPC.
