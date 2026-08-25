# KING ERRICK V4 — gUSD brand first

**Branch:** `cursor/gusd-v4-brand-4f7f`  
**Doctrine:** sequenced sovereignty — brand → sync settlement → mesh → oracle later  
**Oracle rule:** **no $12k / $50k step-up until gUSD + exit proven live**

---

## Live (Base — fired 2026-08-25)

| Piece | Address |
|--|--|
| **gUSD** | [`0x319A49BB274A826F889C6e7221FA82f24ac8bc5d`](https://basescan.org/address/0x319A49BB274A826F889C6e7221FA82f24ac8bc5d) |
| **8020 sync** | [`0x162f5c11C48BFaDab6b8C2963D918A1Bd3f766fb`](https://basescan.org/address/0x162f5c11C48BFaDab6b8C2963D918A1Bd3f766fb) |
| Underlying eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| PoR (ELE77 interim) | `0x3640f1CC913B772EA4D9BDF96a67196590058379` (~$16.5M) |

**Brand proof:** HOT wrapped **1,000 eUSD → 1,000 gUSD** (tx `0x43b4878b…`).

`maxRedeemSync = 0` until Base PSM is seeded — honest LiquidityMiss (by design).

---

## Sequence

1. **gUSD brand** (this PR) — wrap live eUSD 1:1 as Kingdom Gold USD; gold PoR = primary narrative  
2. **8020 sync redeem** — same-tx eUSD→USDC when PSM has reserve (no 7540 queue)  
3. **8888 elephant intents** — interface shipped; fill + ZK in one call (implementation next)  
4. **4-chain mesh** — same VK / TTL across Base + Scroll (+ MegaETH / Berachain later)  
5. **Oracle step-up** — only after (1)+(2) hold on mainnet

---

## Contracts

| Piece | Path | Role |
|--|--|--|
| `CrownGoldUsd` | `src/CrownGoldUsd.sol` | gUSD ERC20, wrap/unwrap eUSD, `goldBackingUsd()` |
| `CrownSyncRedeem8020` | `src/stack/CrownSyncRedeem8020.sol` | IERC8020 sync redeem |
| `IERC8020` / `IERC8888` | `src/stack/interfaces/` | Standards stubs |
| `FireGusdV4` | `script/FireGusdV4.s.sol` | Deploy on Base |

Physics unchanged: Morpho AMO, RSS collateral, ZK gates, Scroll 7540/7683 remain V1 rails. gUSD is the **face**; eUSD is still the **engine**.

---

## Fire (Base)

```bash
KING_GO=1 FIRE_GUSD=1 PRIVATE_KEY=<hot> \
  forge script script/FireGusdV4.s.sol:FireGusdV4 \
  --rpc-url $BASE_RPC_URL --broadcast --slow --with-gas-price 6000000
```

## Tests

```bash
forge test --match-contract GoldUsdForkTest -vv
```

---

## Not in this PR

- $50k / $12k oracle  
- Live 8888 filler  
- MegaETH / Berachain deploy  
- PSM gold vault seed  

No weak plans. Brand first.
