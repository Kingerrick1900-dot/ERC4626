# FIRE — $50M × 2 + cap fill → $200M Morpho depth

**Blueprint executed. No redesign.**

## Loop fires

| Fire | Flash | Depth after | Tx / proof |
|--|--|--|--|
| **#1** | **$50,000,000** | **$143,116,048** | `FireCrownLoopNativeResume` broadcast |
| **#2** | **$50,000,000** | **$193,116,062** | same |
| **#3** | **~$6.88M** (cap fill) | **$200,000,028** | same |

| Meter | Live |
|--|--|
| CrownLoopNative | `0xedBb3bCF…5D3a` |
| **fires** | **97** |
| **totalFlashed** | **≈ $199,983,938** |
| Morpho market depth | **≈ $200,000,028** |
| HOT USDC | **$2.327869** |

## Exit

Pool util ≈ 100% → idle ≈ **$0.01**. Cannot draw millions from empty idle.

Fired Exit on available inventory (Aave sleeve withdraw → fund Exit → exit):

| Step | Result |
|--|--|
| sleeve.withdrawToHot | ≈ $1.33 |
| Exit.fundInventory + exit | [`0x50f5458d…d827`](https://basescan.org/tx/0x50f5458d7610ec96c7ce44c3bde5cdd540e39b901a028cc177ad004c94d3d827) |
| Gate B ($500k) | **locked** (dust exit) |

## Flywheel

Lender + borrower boost scripts **armed**; both refuse pay until Gate B (`Exit > $500k`).

```
FIRE=50m-blueprint ✓
DEPTH≈$200,000,028 fires=97
EXIT=dust (pool idle≈0) gateB=false
FLYWHEEL=armed waiting Gate B
```
