# FIRE — Path B yRSS Idle Forge

**Mode:** FIRE · Base · **LIVE**  
**Doctrine:** Morpho flash → supply onBehalf yRSS → eUSD mint/coll → borrow → repay. Code only.

## Result

| | |
|--|--|
| CrownPathBYrssIdle | `0x0d04B327F571954A5Ac10Dd1f68364C9ac6c4f05` |
| Total forged | **$200,000,000** USDC Morpho inventory into yRSS |
| yRSS totalAssets | **~$246.2M** (was ~$46.2M pre-Path-B) |
| Minter after | **revoked** |

## Hashes

| Step | Hash |
|--|--|
| Prove Safe | `0xec0f98201663181e7796b26fbe12a07cf7befe4f755e92ad05478f6389b37af5` |
| Prove HOT | `0xfcfb0381f3f03ba5fdee912c8e2133fd5671cd0ce9f1317a1c160745a3028599` |
| Deploy forge | `0x1222e07d37d7ccbe949aa6b47100459b2a888e00fd2a0b372cf7f4aacc1adc6f` |
| Forge $5M | `0xa130efb9b917b4b6e968e1f9fa3cbdfc7eabbc2ab809ddb62dbcce02d919d7cf` |
| Forge +$10M | `0x23944fd020aed0ed12c9f7ac867ebf820e69ab5f407d004c6f7423ad506c6ce1` |
| Forge +$10M | `0xc37a3a12d6cdecb157a381e9d401377a260f0b9fa4a922ab2ff48dd83412041c` |
| Stage setMinter on | `0x2f16423e074533e8799b8d6304142713cc09488a083d604680edeb2cbfffde00` |
| Stage forge +$175M | `0x883b1bdef9565086a22456413707f6298b7709ff5909a5a67a1b284ff1955278` |
| Stage setMinter off | `0x9cfe78b449f382f347a01361c12086643a69c9965ffb319ddda743a6183def63` |

## Ops

- Reuse forge via `FirePathBStageYrss` (`FORGE_ADDR` · no redeploy).
- HOT ETH reserved (~0.00014 left after stage).

## Next

Seed KRT/USDC Ocean + PAR from yRSS idle. Nigeria/allocator after real USDC exit.
