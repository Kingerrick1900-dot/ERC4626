# Multi-Asset PSM — Base LIVE

**Branch:** `cursor/psm-multi-asset-efa1`  
**Doctrine:** Extend accepted PSM assets to **USDT / DAI / ETH / EURC** via existing Chainlink feeds.  
**Constraint:** ERC-7540 (`CrownElepanAsyncVault`) and ERC-7683 (`CrownPsmIntentSettlement`) **source + live Scroll instances unchanged**.

---

## Contract

| Item | Value |
|--|--|
| Contract | `CrownMultiAssetPsm` |
| Chain | Base (8453) |
| Address | [`0xF7337A26d9456e42a36531A12036A4556EF1F987`](https://basescan.org/address/0xF7337A26d9456e42a36531A12036A4556EF1F987) |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Owner | King hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Deploy tx | [`0xd240e0e3…cea46a`](https://basescan.org/tx/0xd240e0e35cfd0024e4fa4a78f3a8adafa78ebe4b9f8b57bf3ed672951fcea46a) |

### Live quotes (1 eUSD → asset, verified post-deploy)

| Asset | Out |
|--|--|
| USDC | ~1.000234 |
| USDT | ~1.001151 |
| DAI | ~1.00024 |
| WETH | ~0.00053 (~$1 / ETH feed) |
| EURC | ~0.868478 |

Reserves: empty until seeded (hot had 0 of each token at deploy).

---

## Accepted assets (Chainlink)

| Asset | Token | Decimals | Feed | Path |
|--|--|--|--|--|
| **USDC** | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | 6 | `0x7e860098…bc6B` USDC/USD | `redeemUsdc` / `redeemAsset` |
| **USDT** | `0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2` | 6 | `0xf19d560e…21F9` USDT/USD | `redeemAsset` |
| **DAI** | `0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb` | 18 | `0x591e7923…C78F` DAI/USD | `redeemAsset` |
| **ETH** | WETH `0x4200…0006` | 18 | `0x71041ddd…Bb70` ETH/USD | `redeemAsset` (WETH) / `redeemEth` (native) |
| **EURC** | `0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42` | 6 | `0x8438ee84…4d13` capped EURC/USD | `redeemAsset` (`useLatestAnswer=true`) |

EURC feed uses **`latestAnswer()`** — `latestRoundData` reverts on the capped adapter.

---

## 7540 / 7683 reuse (unchanged)

- Live Scroll vault `0x846E34…434D` and settler `0x44F922…15A83` stay pointed at Scroll Gold Parity PSM `0x064489…75dA`.
- `CrownMultiAssetPsm` exposes the same surface the vault needs: `eusd()`, `usdc()`, `redeemUsdc(amt,to)`, `usdcReserve()`.
- Optional: deploy a **new** `CrownElepanAsyncVault` instance (same bytecode, no source edits) with `psm_ = CrownMultiAssetPsm` for a Base USDC async queue. USDT/DAI/ETH/EURC remain direct `redeemAsset` / `redeemEth` calls.

---

## Fire

```bash
KING_GO=1 forge script script/FireMultiAssetPsm.s.sol:FireMultiAssetPsm \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Seeds dust from hot wallet when balances exist; skips otherwise.

---

## Tests

```bash
forge test --match-contract MultiAssetPsmTest
# 9/9 — USDC/USDT/DAI/WETH/ETH/EURC + 7540 wrap + stale feed
```
