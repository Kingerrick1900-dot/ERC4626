# Phase 3 — Strike + Enroll (Revenue First)

Correct order: **Strike + Enroll → Scale → Real lenders**.

## Strike (Hostile)
- Fleet signer: `0xcbD8…` · Morpho flash liquidator · `LIVE=true`
- Fires when **on-chain HF < 1** (backrun holds while HF > 1)
- Telegram: `strike status` · `strike clear` · `fire 0x…` · `find-fire`
- Gas: fleet must hold ETH (topped 2026-07-13 → ~0.00087 ETH)

## Enroll (VIP Rescue)
- Opt-in only · fee **7%** · excluded from hostile queue
- Telegram: `rescue status` · `rescue pitch` · `rescue enroll 0x…` · `rescue invoice` · `rescue remove 0x…`
- `fee_accrued` = ledger until settled cash arrives (invoice/off-chain/settle path)

## Scale (later)
- Morpho desk already ~$512.5k circular · HF ~1.54
- `morpho status` / quiet scaler armed

## Real lenders (last)
- Quiet only — no public lure spam
