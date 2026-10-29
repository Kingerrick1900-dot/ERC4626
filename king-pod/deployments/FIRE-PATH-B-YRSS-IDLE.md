# FIRE — Path B yRSS Idle Forge

**Mode:** FIRE · Base · **LIVE**  
**Doctrine:** Morpho flash → supply onBehalf yRSS → eUSD mint/coll → borrow → repay. Code only.

## Forge

| | |
|--|--|
| CrownPathBYrssIdle | `0x0d04B327F571954A5Ac10Dd1f68364C9ac6c4f05` |
| Total forged | **$25,000,000 USDC** (Morpho inventory in yRSS) |
| yRSS totalAssets | **~$71.2M** (from ~$46.2M) |

## Hashes

| Step | Hash |
|--|--|
| Prove Safe | `0x...` (FireZkProveSafe run-latest) |
| Prove HOT | `0x...` (FireZkWalletRefresh run-latest) |
| Deploy+forge $5M | FirePathBYrssIdle run-latest |
| Forge +$10M | `0x23944fd020aed0ed12c9f7ac867ebf820e69ab5f407d004c6f7423ad506c6ce1` |
| Forge +$10M | `0xc37a3a12d6cdecb157a381e9d401377a260f0b9fa4a922ab2ff48dd83412041c` |

## Note

HOT ETH low — further tranches need gas top-up. Minter revoked on forge after each fire.
