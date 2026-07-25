# Create the market — kingdom engineering (not waiting)

United Provinces of Digital Yahudah — timestamp by deployment. The machines curate; the king orders.

## DeepSeek bypass vs chain

| Claim | Live engineering |
|--|--|
| “Emergency acceptCap is instant” | On **yELE** (timelock 48h) pending WETH `validAt` still binds. **Instant path:** deploy **new** MetaMorpho with `timelock=0` → `submitCap`+`acceptCap` same tx. |
| “PreLiquidation engineers USDC without liquidity” | PreLiq still needs **USDC to repay debt** (flash ok). Self-preliq + withdraw supply = **deleverage**, not net dollars to Landing. No ELE DEX to sell seized coll. |
| “Just call `reallocateTo` — it’s public” | Public **yes** — but needs vault **supply** on source + **flow caps** + dest market **enabled**. Empty vault → no pull. |
| “New oracle / PreLiquidationOracle” | New oracle ⇒ **new Morpho market id**. Headroom ≠ idle. Does not mint USDC. |

## What we fire (create-market)

```bash
KING_GO=1 FIRE_CREATE_MARKET=1 \
forge script script/FireCreateKingdomMarket.s.sol:FireCreateKingdomMarket \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Creates:
1. `yELE-K` MetaMorpho (timelock **0**)
2. Instant WETH/USDC + ELE/USDC caps ($50M)
3. Supply queue WETH → ELE
4. PA allocator + `$700k` maxIn/maxOut both markets
5. Fee recipient = Landing

Fork: `CreateKingdomMarketForkTest`.

## After create

Vault is the market shell. Dollar fill still needs **sized USDC** into the vault (PSM / Morpho idle / PA foreign / wire) — then curator `reallocate` + borrow → Landing. No Gauntlet wait for the **shell**.
