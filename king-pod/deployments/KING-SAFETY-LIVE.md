# KING SAFETY — LIVE (no multisig)

**Goal:** Protect Morpho + prime stack. Self-liq path on. Flash dead.

## Live flags

| Control | Status |
|---------|--------|
| Morpho `isAuthorized(HOT, HOT)` | **true** (self) |
| Morpho flash engine auth | **false** |
| Credit flash operator | **false** |
| Borrow router `armed` | **false** |
| Clean credit debt | **$0** |
| Reserved debt | **$0** |

## Self-guard

| | |
|--|--|
| **CrownMorphoSelfGuard** | `0x0Dd38dcF3A6C5dD03790380A8365F8e012929935` |
| Morpho authorized | **true** |
| Powers | `selfRepay` / `selfPullColl` (king-only) |

Emergency repay (when USDC is on HOT):

```bash
SELF_GUARD=0x0Dd38dcF3A6C5dD03790380A8365F8e012929935 \
MARKET=rss AMT=<usdc_raw> PRIVATE_KEY=0x… \
  bash king-pod/script/FireMorphoSelfRepayCast.sh
```

`MARKET=eusd` for the eUSD/USDC book.

## Still true

- RSS1200 ~$201M borrow = real liquidation surface — repay only with **real USDC**
- eUSD Morpho = 40M coll / $0 borrow → no liq risk until borrow
- No multisig yet (per king order)
- Aero LP still on HOT EOA

## Tx refs

- revoke flash Morpho: [`0x5c200c16…`](https://basescan.org/tx/0x5c200c16bb2bc80fa1f394d158c53611b48ada35a27c98264dc0bf75201dd4c7)
- self-auth Morpho: `0x328d32590d5a99dca1c3b59b9bed6e6509e4d7c5faded224f8097743b3dc5406`
- deploy + auth guard: see `broadcast/FireMorphoSelfGuard.s.sol/8453/run-latest.json`
