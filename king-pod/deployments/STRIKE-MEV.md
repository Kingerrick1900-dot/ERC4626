# STRIKE / MEV — back on the board (legal protocol rail)

## Correction
MEV backrun and Morpho liquidation were wrongly framed as crook shit. **They are not illegal.** They are how Morpho, Aave, Euler, and Flashbots searchers keep lending markets solvent. King has a **real protocol**. Strike is protocol revenue — not theft.

## Who uses the same tactics
- **Morpho Labs** ships `@morpho-org/liquidation-sdk-viem` — official liquidator examples with Flashbots
- **Production Morpho liquidators** on Base/mainnet: flash Morpho USDC → `Morpho.liquidate` → swap collateral → repay → keep bonus
- **Aave / Euler / Silo** keeper bots — same pattern industry-wide
- **Flashbots** — private backrun bundles so searchers compete without public mempool spam

On-chain HF < 1 → liquidate is **in the Morpho contract**. Calling it and keeping the liquidation incentive is **the design**.

## Kingdom already built this
Phase 3 Strike desk (fleet `0xcbD8…`):
- Morpho flash liquidator
- Backrun hold while HF > 1
- Fire when on-chain HF < 1
- Telegram: `strike status` · `find-fire` · `fire 0x…`

VIP enroll is optional opt-in. Strike hostile queue is the **open market** keeper path elites run.

## Fee / profit path
1. Scanner finds Morpho Base position HF < 1
2. Bundle: flash USDC → liquidate → swap seized collateral → repay flash
3. **Profit → KingVault** `0xA1aF…832a`
4. CrownFlashRouter can sit under the flash leg so **router fee also hits vault**

## What to arm (worker)
- Point Strike profit receiver to KingVault
- Point CrownFlashRouter treasury to KingVault (ArmKingdomFees)
- Keep fleet gas funded
- LIVE strike on Base Morpho markets with real collateral (cbBTC/WETH/USDC books — where the size is)
- Private/relay submission where available on Base

## Not crooks
Liquidation bonus is paid by the protocol to whoever closes unhealthy debt. King running Strike is **the same job** Morpho’s own SDK documents. Real protocol. Real fees.
