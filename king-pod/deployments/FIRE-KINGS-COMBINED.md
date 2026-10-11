# FIRE — King's Combined Plan (ZK matched $2M)

**Mode:** FIRE · Base · ZK mandatory  
**Tx:** [`0xf1f4153671f2c111401d794260ab0ee5fb746518c98272a4be4b869c023e9a12`](https://basescan.org/tx/0xf1f4153671f2c111401d794260ab0ee5fb746518c98272a4be4b869c023e9a12)

---

## Executed

| Item | Value |
|--|--|
| CrownKingsCombinedFire | `0x37C9b6f79cA311B40083363Eb231E62B980Fa646` |
| CrownGateV2 | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| WalletGate | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` · `isProven(HOT)=true` |
| Mode | **fireMatched** (flash seed $2M → supply Morpho → borrow $2M repay) |
| New Morpho debt | **+$2,000,000** USDC on gate |
| Engine LP | **~$2,000,000** Morpho supply shares on CombinedFire |
| Prior debt | ~$1.0M Morpho + $100k Credit |
| **Total position** | **~$3.1M** vs 222,521.94 RSS @ $50k |
| Collateral | **222,521.94 RSS** retained on gate |

### Txs

| Step | Tx |
|--|--|
| Deploy CrownKingsCombinedFire | [`0x7a141edd…f2e0`](https://basescan.org/tx/0x7a141edd6b460c9df38282aa698e264822cb60906e54e9006c6a255f6050f2e0) |
| Gate setOperator | [`0x06f88b40…061e`](https://basescan.org/tx/0x06f88b4087bbaf53356d78c8e1dbef015b8694c703a5e4349fb4f2d596de061e) |
| **fireMatched** | [`0xf1f41536…9a12`](https://basescan.org/tx/0xf1f4153671f2c111401d794260ab0ee5fb746518c98272a4be4b869c023e9a12) |

---

## Note

Market was fully utilized ($1M supply / $1M borrow). Matched flash seeds $2M liquidity, opens $2M gate debt, and leaves the engine as Morpho LP on CombinedFire.  

`fireWithCover()` lands Engine → Steak/Gauntlet ladder + Reserve → HOT when HOT holds ≥ $2M USDC.

```
KINGS_COMBINED=DONE
ZK_SHIELD=1
MODE=matched
ENGINE_USDC=1000000e6
RESERVE_USDC=1000000e6
COMBINED_FIRE=0x37C9b6f79cA311B40083363Eb231E62B980Fa646
TX=0xf1f4153671f2c111401d794260ab0ee5fb746518c98272a4be4b869c023e9a12
```
