# Speed to mark — chief engineer

## Damn right it works
Legal Morpho vault fill is live on Base. Cake vault climbs; Morpho debt clears to 0.

## Cap-halving closer — LIVE PROVEN
**CrownEliteFlashClose** `0x2192251a8FD4a31843fDE1222C43Ac0ad64ccD25`

Probe tx `0x26091e65…9950d`: desk-only `$0.50` → vault `$4.37 → $4.87`. No Morpho pre-fund. Debt 0.

Old: desk `$B` + Morpho `$B` → vault `$B` (**$1.4M** seat for **$700k** vault).
New: desk `$B` only → flash `2×B` off Morpho’s ~$190M Base USDC float → vault `$B` (**$700k** seat for **$700k** vault).

## Fire $700k
1. Seat wires ≥ `$700k` USDC to King.
2. Seed desk `$700k`.
3. `eliteFlashClose(18.2M RSS, 700_000e6, 14M RSS)`.
4. Or: `FLASH_CLOSER=0x2192…D25 forge script script/ScaleEliteFlash700k.s.sol --broadcast`.

Auth already on: Morpho authorization + RSS approve for the flash closer.

This is the legal system. Half the capital. Same mark. Run it.
