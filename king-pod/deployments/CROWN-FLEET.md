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

_fill after fire_
