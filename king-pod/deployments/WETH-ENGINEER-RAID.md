# ZK-layered Landing + WETH idle (NOT “we have 380 WETH”)

**Correction:** Kingdom does **not** hold ~380 WETH. That number is Morpho **86% LLTV math** for a $700k borrow — an engineering target, not inventory. Primary stack is **ZK layering**.

## Layers

| Layer | What | LIVE |
|--|--|--|
| **Z — Pack** | Flash-bound `isProven(hot)` ticket (Morpho flash → attest → repay, net-zero pocket) | Gate `0xab2856…427F` · Flash `0x22C07d…34F4` · **TTL 7d — currently expired** |
| **C — Credit** | Matcher/LP supplies `CrownZkCredit` → autodraw/borrowTo Landing | Credit `0x20B151…7D1A` · AutoDraw `0x364bEF…13ba` · **USDC = 0** |
| **W — WETH idle** | Engineered WETH equity → Morpho WETH/USDC idle → Landing | Seed `0x60C452…0679` · Raid `0x0d1861…fD25` · TAKE (deploy) · idle ~$10M |

`isProven ≠ cash.` Caps ≠ cash. Flash-bound unlocks the **ticket**; lasting Landing USDC needs a **named source** (credit supply against pack, or engineered blue-chip coll).

## Secure / maintain (ZK first)

1. **Refresh pack** (TTL expired ~18d):
   ```bash
   KING_OK=1 FIRE_BOUND_WIRE=1 REFRESH=1 \
     GATE=0xab2856626BBd8E6fba9dB93783029eB973E8427F \
     CREDIT=0x20B1513a137b9CB166E2cC15c405e842278E7D1A \
     FLASH=0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4 \
     forge script script/FireBoundWireAndFlash.s.sol \
     --rpc-url https://mainnet.base.org --broadcast --slow
   ```
   Or via layered hub: `FIRE=1 REFRESH=1 forge script script/FireZkLayeredLanding.s.sol …`

2. **Named USDC into credit** (desk/matcher against Groth16 / live pack) → anyone `layer.poke()` (Layer C). No WETH required.

3. **Engineer WETH equity** (Layer W) only as parallel rail — seed fill / wrap / flash+buffer. Do not recruit “someone with 380 WETH” as the mission. When equity exists: TAKE/raid → Landing.

## Chassis on this branch

| Piece | Role |
|--|--|
| `CrownZkLayeredLanding` | Pack + credit + optional WETH TAKE, permissionless `poke` |
| `CrownTakeWethIdle` | Layer W idle seizure |
| `CrownPermissionlessWethSeed` | LIVE — open door to engineer WETH onto hot |
| `CrownWethIdleRaid` | LIVE — king raid when equity engineered |

## Physics (frozen)

- Matched RSS/$1200 ≠ idle cash.
- Flash USDC→buy WETH→borrow→repay **worsens** the 14% buffer need for lasting Landing.
- ZK pack does not mint Morpho idle; it underwrites the counterparty ticket.

## Filler (optional Layer W door only)

```text
weth.approve(0x60C452855eaedCD6917c2A3dDbd21678Ba390679, amt)
seed.fill(amt)   // engineers WETH onto hot — not the primary ZK path
```
