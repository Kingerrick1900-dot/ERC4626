# PLAY 5 — Self-Supply Boost (armed, waiting King OK)

## Pick
Self-Supply Boost. Morpho `supply(onBehalf=…)` then withdraw. Standard Morpho flow.

## How it fires when King says OK
King (or rail) holds USDC. Script supplies that USDC into the RSS/USDC Morpho market on behalf of the chosen address (default LiquiditySink / CrownCrossFlash / King). That raises market float. Then withdraw the same supply assets back out to KingVault or King hot — or leave them posted as the seed leg for Play 3 borrow-to-vault.

Two modes after OK:
1. **Boost only** — supply onBehalf, stop. Float sits in market for Play 3 borrow.
2. **Boost and pull** — supply onBehalf, then withdraw assets to KingVault (round-trip relocate; net ~0 unless paired with Play 3 borrow hold).

## Why it sits with Play 3
Play 3 needs idle USDC in the RSS market. Play 5 is how King-controlled USDC becomes that idle without waiting on a curator. Play 5 does not invent USDC. It places USDC King already has (or a repay rail holds) into the book.

## Status
Armed. Script ready. No deploy or broadcast until King OK / go.
