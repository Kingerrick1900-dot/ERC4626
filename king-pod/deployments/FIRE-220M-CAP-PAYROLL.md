# FIRE — yRSS $220M cap + payroll

**Mode:** FIRE · executed on Base  
**Doctrine:** Same move elite MetaMorpho curators make — **raise the vault market supply cap** so the vault *may* hold the size; capital still has to flow in. Cap ≠ TVL.

---

## Live results

| Action | Tx | Result |
|--|--|--|
| `submitCap(PARK, $220M)` | [`0x9c707fe0…74d31`](https://basescan.org/tx/0x9c707fe0402d41558ddb45eb249c2cee85b1fa4ae216b4d5fddc581aefe74d31) | success |
| `acceptCap(PARK)` | [`0xeb7e3f9d…a9bcf`](https://basescan.org/tx/0xeb7e3f9d94c3a477de39780656a21c2a008c82bbf2f40950440ff5e8824a9bcf) | **cap = $220,000,000** |
| PA `setFlowCaps` maxIn/Out $220M | [`0xcd291370…95f5b`](https://basescan.org/tx/0xcd29137066143044918d6e1ebf24998e104f10506edd5e659f0ef3b9ddf95f5b) | **220M / 220M** |
| `CrownKingAgent.firePayroll(10M eUSD)` | [`0x090335b0…dbca9`](https://basescan.org/tx/0x090335b0e766a9fb2f4157af16301719e1de3f49e5f3fd35db8876ff780dbca9) | **+10,000,000 eUSD → Landing** |

### Verified reads
- yRSS `config(PARK).cap` = `220_000_000e6`
- PA `flowCaps(yRSS, PARK)` = `220M / 220M`
- Landing eUSD = `1,514,450,370,221,800,120,394,502,348` (+10M e18)
- HOT nonce after = **2131**

### Market params (PARK)
`USDC / RSS / oracle 0xB584…E1B9 / IRM AdaptiveCurve / LLTV 77%`  
Market id `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88`

---

## Elite-protocol note

Yes. Steakhouse, Gauntlet, and other MetaMorpho curators **set and raise per-market supply caps** on their vaults. Morpho Blue has no $14M ceiling — that was the King’s prior curator choice. Raising to $220M is the standard unlock so yRSS *can* become the dominant supplier. **Filling** toward 87.5% still needs deposits / PA inflows; the matched book does not teleport into the vault when the cap moves.

---

## Still open
- yRSS share of PARK book still ~**0.5%** until capital arrives  
- MEV micro-hunt not deployed (next lift)
