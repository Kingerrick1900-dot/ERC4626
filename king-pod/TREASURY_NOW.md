# Treasury motion — Crown orders

## Fee
Rescue fee **5%** (`RESCUE_FEE_PCT=0.05`).

## Open desk (no hand invites)
`rescue-open-enroll` auto-tags near-liq whales into `pipeline` at 5%.
Pipeline does **not** block hostile strikes (lesson: earlier active enroll starved the hunter).

## Cash reality (this window)
- Fleet/King USDC spendable ≈ **$0**
- Morpho circular book ≈ **$512k** (not spendable)
- `find_and_fire`: **no HF < 1** targets in DB right now → no liquidation print this tick
- 5% rescue cash prints only when a rescue/hostile fill actually settles

## Commands
Telegram still: `strike status`, `rescue status` (fee ledger at 5%).
