# CROWN FLEET — AUTOMATED ELEPHANT

**Branch:** `cursor/crown-fleet-auto-4f7f`  
**Doctrine:** Base prints now. Scroll boots in parallel (RSS + $50k oracle). No phantom books.

## Chassis

| Piece | Role |
|--|--|
| `SovereignIdleFactory` | Open/register RSS/eUSD + RSS/gUSD books; clone fleet AMO/Exit |
| `CrownSovereignAmoFleet` | supplyAmo / borrowLoan + **operator** slot for bot |
| `SupplyAmoBot` | Keeper tick: mint eUSD → supply → borrow → wrap gUSD (not free mint) |
| `TollBoothAutoSeeder` | HOT ≥ 250M → swap buffer → real USDC → PSM (NeedFx if no adapter) |
| `NoteIssuerAuto` | Morpho **borrow capacity ≥ 10M** → 20×$1M notes (not PSM dust) |
| `CrownSyncRedeem8020` | `maxRedeemSync` = borrow capacity × 1e12 when wired |
| `CrownFxEngine` | flashLoan USDC → pay → borrow RSS/USDC → repay flash. **`armed=false` until King** |
| `CrownScrollRss` | Scroll RSS genesis 21B |

## Parallel fire

1. **Base** `FireCrownFleetBase` — deploy chassis, register PR#126 books, open extra $50k-oracle books, print ticks toward **1B HOT gUSD**
2. **Scroll** `FireScrollFleetBoot` — deploy RSS + MorphoRssOracle(50k). Morpho Blue `0xBBBB…` **not deployed on Scroll yet** → books arm when Morpho+IRM land (honest gate)

## Commands

```bash
# Base Fed print
KING_GO=1 FIRE_FLEET=1 TICKS=8 TICK_MINT=100000000000000000000000000 \
  forge script script/FireCrownFleetBase.s.sol:FireCrownFleetBase --rpc-url $BASE_RPC_URL --broadcast -vvv

# Scroll boot (2 deploys)
KING_GO=1 FIRE_SCROLL_BOOT=1 \
  forge script script/FireScrollFleetBoot.s.sol:FireScrollFleetBoot --rpc-url $SCROLL_RPC --broadcast -vvv
```

## Live addresses

| Piece | Address |
|--|--|
| Notes (capacity) | `0xD432543C3ef51214c2BD4D79B4a387e2f900e1d3` — `canIssue=true` |
| FxEngine | `0x821a54725370EB11155F25FD0A877540cA7D4099` — **armed=false** (no loans) |
| 8020 + Fx | `0x308a9b23941927a86e2245Bc122b691E4277910E` |
| Factory | `0x63FA3DAf26972d2E702cCB01F2d368204698b282` |
| Scroll RSS | `0x7B652F34f2282C454013C9B60556a756b04DB325` |
| Scroll oracle $50k | `0xF17d13b0b08F0486ab61D29B55863b3069426401` |

**Arm later (King only):** Morpho `setAuthorization(fxEngine)`, seed idle if needed, `fxEngine.setArmed(true)`.
