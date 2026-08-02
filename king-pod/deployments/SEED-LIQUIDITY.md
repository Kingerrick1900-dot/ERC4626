# feat/seed-liquidity — KESOV Mainnet Activation

**PR:** one package · **Scripts:** two · **Commands:** two

| Script | Network | Job |
|--------|---------|-----|
| `scripts/seedEthPool.ts` | Ethereum | Seed L1 eUSD/WETH Uni V3 (50k / 15, fee 500, full range) |
| `scripts/seedBasePsm.ts` | Base | Capitalize Maker PSM via `mint` ($25k USDC → reserve + eUSD) |

## Live anchors

| Piece | Address |
|-------|---------|
| Base PSM | `0xfFEd7981f924Edc652E9b767aCa601505dfa4977` |
| Base USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| L1 WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| L1 NPM | `0xC36442b4a4522E871399CD717aBDD847Ab11FE88` |
| L1 eUSD | **set `EUSD_L1`** — Base eUSD is not on Ethereum |

## Run

```bash
npm install

# Step 1: Seed L1
EUSD_L1=0x… npx hardhat run scripts/seedEthPool.ts --network mainnet

# Step 2: Capitalize PSM
npx hardhat run scripts/seedBasePsm.ts --network base
```

Optional: `USDC_AMOUNT=25000` · `MODE=seed` (seedUsdc only) · `EUSD_AMOUNT` / `WETH_AMOUNT`.

## Preflight (honest)

- Hot Base USDC is dust after WIRE seed — fund **$25k** before Step 2.
- L1 eUSD must exist and be funded (50k eUSD + 15 WETH) before Step 1.
- Scripts exit loud if balances are short — no silent partial fire.
