# SOVEREIGN IDLE PRODUCT — LIVE

**Fired:** 2026-08-25  
**Branch:** `cursor/sovereign-idle-product-4f7f`  
**Doctrine:** Idle is minted, not waited for. USDC optional FX later.

## Result

| Book | Supply | Borrow | Idle | Proven |
|--|--|--|--|--|
| RSS/eUSD/$50k (scaled) | **~200.70M** | **~167.68M** | **~33.02M** | true |
| RSS/gUSD/$50k (**NEW**) | **100.00M** | **70.00M** | **30.00M** | true |

### HOT float (post-fire)

| | Amount |
|--|--|
| HOT gUSD | **~220.91M** |
| HOT eUSD buffer | **~16.77M** |
| eUSD totalSupply | **~301.9M** |

### Addresses

| Piece | Address |
|--|--|
| eUSD AMO (scaled) | `0x8960BdbE760E6C90c53a912063170a2Efb1df4Ed` |
| **gUSD market ID** | `0x5dd0f7c171f7de8899ca1025bfd9ee2fe2153762c532b691b1bdb344f46227cf` |
| **gUSD AMO** | `0x380E199070A329ADefADB43F1932Da301FFC767d` |
| **gUSD Exit** | `0x041416a763bDc02F396bEe05712DacE63B9B0B89` |
| gUSD token | `0x319A49BB274A826F889C6e7221FA82f24ac8bc5d` |
| Oracle $50k | `0x264f7AfB8f12028345B87FD5E58F2CF444EebA90` |

## Path executed

1. Mint **100M eUSD** → Landing → `supplyAmo` on live $50k AMO → idle **110.07M**
2. Borrow **70%** (~77.05M eUSD) → wrap **90%** (~69.34M) → gUSD face
3. `createMarket` RSS/gUSD/@$50k → deploy AMO + Exit
4. Mint **100M eUSD** → wrap → Landing gUSD → `supplyAmo` → **100M gUSD idle**
5. Peel **100k RSS** from eUSD book → post on gUSD → borrow **70M gUSD** to HOT
6. Re-arm `requireGate=true` on gUSD AMO

## Physics

- gUSD = wrap(eUSD) — no free mint of brand face
- Morpho idle ≠ wallet cash; borrow pulls idle → HOT
- RSS coll USD mark at $50k still ≫ debt (LTV tiny)
- USDC not used. Scroll deferred until RSS Morpho-ready

## Replay

```bash
KING_GO=1 FIRE_IDLE=1 forge script script/FireSovereignIdleProduct.s.sol:FireSovereignIdleProduct \
  --rpc-url $BASE_RPC_URL --broadcast -vvv
```

Fork proof: `forge test --match-contract SovereignIdleProductFork -vv`
