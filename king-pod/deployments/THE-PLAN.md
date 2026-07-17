# THE PLAN (locked)

## Name
**Flash leftover → vault**

## Why this one
Every Morpho “seed then borrow RSS” version is the same dead loop. Killed.
Wallet has: **~18.5M RSS**, **~$4.87 USDC**, dust ETH/gas. No WETH/cbBTC size for deep markets.

## Machine (already live)
1. Morpho flashes USDC into `CrownFlashArb` for one tx.
2. Arb buys cheap / sells high on Base.
3. Repays Morpho in the same tx.
4. Leftover USDC → King treasury/vault.

Contracts:
- Router `0x13734BffdDFf6CbDE474B3F5467d86e813232577`
- Arb `0xD17D5aF60fDF495C50E5aced46CdC1C0E68F366d`

## Steps
1. King says **GO**.
2. Scribe arms scanner: only fire when profit > fee + gas + cushion.
3. Hits land hard USDC in vault.
4. No hit = no tx. No dust theater.

## Not this plan
- Seed King’s RSS Morpho market then borrow
- Elite-close dust loops
- Liquidation bots
- Public depositor pitches

Greenlight = start. No greenlight = parked.
