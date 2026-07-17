# Plan C — Execution (hard USDC, no buyers, no paper LP)

## Objective
Earn **real Base USDC** from Morpho liquidations → land on vault. Debt 0. No RSS buyer. No V1 paper.

## Why this one
- Morpho official path: [morpho-blue-liquidation-bot](https://github.com/morpho-org/morpho-blue-liquidation-bot)
- Free Morpho flash loans → liquidate underwaters → keep liquidation premium in USDC
- Industry norm (keepers), not a dust loop, not stranded sUSDC

## Execution order

### 1. Deploy executor
- Deploy Morpho/Rubilmax executooor on Base, owner = King.
- Treasury / skim recipient = vault `0xA1aF…832a` (or King hot then one-shot to vault).

### 2. Wire bot (Base only)
- Clone Morpho liquidation bot.
- Config: chainId `8453`, RPC Base, `EXECUTOR_ADDRESS`, `LIQUIDATION_PRIVATE_KEY` = King key already in use for fires.
- Liquidity venues: Uniswap V3/Aerodrome as supported.
- Pricers on — skip unprofitable (gas > premium).
- `treasuryAddress` = vault.

### 3. Run keeper nonstop
- Bot watches Morpho Blue markets on Base every block.
- On liquidatable + profitable: flash → liquidate → swap coll → repay → skim USDC to vault.
- Log every hit: tx, USDC profit, vault balance.

### 4. Stack vault
- Every skim increases vault hard USDC.
- No desk seed required for this income path.
- Elite-close machine stays parked until there’s a separate hard-USDC rail worth firing.

## Kill list
- Buyer wait / RSS sale hopium
- V1 “$170k” paper sUSDC rescue as cash plan
- Dust elite-close spins
- Empty-rail fire-duty

## Done when
Bot live on Base, first profitable liquidation skimmed to vault, Morpho debt on King stays 0.
