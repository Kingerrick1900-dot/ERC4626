# LIVE FIRE PACKAGE — RWA Loop + Ocean Arb + Flash Leverage

**Status:** ARMED FOR DEPLOY · Pilot **10M** · Ceiling **35M yRSS** (no fake 90M)  
**Doctrine:** Real USDC only into engines. ZK_SHIELD on every fire. Yield → `CrownColdBuffer`.

## Board (pre-fire)

| Check | Live |
|--|--|
| yRSS `totalAssets` | ~$266M (Path B matched inventory) |
| HOT `maxWithdraw` | **dust (2)** — matched book, not free cash |
| Spec capital | **35M** attributable yRSS bag — **not** 90M buyers |
| Pilot | **$10,000,000** USDC hard cap on `CrownRwaLoop` |

**Blocker for yRSS pull:** need free IDLE sleeve or HOT USDC seed before `FIRE_RWA_PILOT`. Flash leverage seats RWA debt book when Morpho flash + swapper + market are live.

## Yield thesis (package)

| Engine | Spec |
|--|--|
| RWA Loop | 30M yRSS → ~73.8M USDY @ 85% LTV · ~$1.63M/yr spread |
| Ocean Arb | 9M POL (3×3M Base/Poly/Scroll) · 0.2% × rotations · ~$19.7k/day |
| Flash Leverage | Atomic Morpho repay · ~$900k/yr |
| **Total** | **~$5.53M/yr** real USDC → ColdBuffer |

Pilot fires **10M** first; scale only after ColdBuffer receives real USDC.

## Contracts

| Contract | Role |
|--|--|
| `CrownColdBuffer` | Yield sink → Landing/King |
| `CrownRwaLoop` | yRSS/seed/flash → USDY Morpho loop @ ≤85% |
| `RwaSwapAdapter` | USDC ↔ USDY router adapter |
| `OceanArb` | Per-chain 3M sleeve · keeper `rotate` |
| `MorphoFixedOracle` | USDY/USDC Morpho price |
| `keeper/ocean-arb` | Node keeper Base/Poly/Scroll |

## Addresses (fill after deploy)

| | |
|--|--|
| ColdBuffer | _pending_ |
| CrownRwaLoop | _pending_ |
| RwaSwapAdapter | _pending_ |
| USDY Oracle | _pending_ |
| OceanArb Base | _pending_ |
| OceanArb Polygon | _pending_ |
| OceanArb Scroll | _pending_ |
| Morpho marketId | _pending_ |
| ZK Gate | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` |
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| USDY (Base) | `0xC6682C8B7cbB363562Bd1FF1C1Ad50d66f5BAEDA` |

## Execution order

1. **Deploy Base package**  
   `DEPLOY_LIVE_FIRE=1 ZK_SHIELD=1 HOT_KEY=0x… CREATE_MARKET=1 forge script script/DeployLiveFirePackage.s.sol --rpc-url $BASE --broadcast`

2. **Deploy OceanArb Poly + Scroll**  
   `DEPLOY_OCEAN=1 … forge script script/DeployOceanArbChain.s.sol --rpc-url $POLY|--broadcast` (repeat Scroll)

3. **Init keeper**  
   `cd keeper/ocean-arb && npm i && OCEAN_BASE=0x… OCEAN_POLYGON=0x… OCEAN_SCROLL=0x… DRY_RUN=1 npm start`  
   Then drop `DRY_RUN`, set router route data, `setArmed(true)`, seed 3M/chain when free USDC exists.

4. **Attach ZK**  
   Gate already wired in deploy (`setGate`). Re-prove HOT + Safe if TTL stale before fire.

5. **Prepare 10M pilot**  
   - Wire `RwaSwapAdapter.setRouter` to live USDC/USDY pool  
   - Confirm Morpho market liquidity / createMarket  
   - Free USDC sleeve **or** HOT seed **or** `USE_FLASH=1`  
   - `FIRE_RWA_PILOT=1 ZK_SHIELD=1 LOOP=0x… ASK_USDC=10000000000000 forge script script/FireRwaPilot10M.s.sol --broadcast`

## Kill switches

- `setArmed(false)` on loop / ocean  
- `pilotCap` ≤ 35M forever  
- Minter/auth revoke after flash paths  
- No fire if `ZK_SHIELD` / borders / gate fail  

## Next after pilot green

Scale RWA toward 30M seat · seed Ocean 3×3M · keeper live rotations · ColdBuffer withdrawToLanding.
