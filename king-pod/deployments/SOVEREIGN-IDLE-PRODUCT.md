# SOVEREIGN IDLE PRODUCT — LIVE FIRE

**Branch:** `cursor/sovereign-idle-product-4f7f`  
**Doctrine:** Idle is minted, not waited for. USDC is optional FX later.

## Plan (executed)

1. **Scale live RSS/eUSD/$50k** (`0x6075ba26…` / AMO `0x8960BdbE…`)
   - HOT mints eUSD → Landing → `supplyAmo` → unmatched idle same block
   - Borrow 70% of idle → HOT → wrap 90% → gUSD face
2. **Open RSS/gUSD/$50k** (loan token = wrap of eUSD, not free mint)
   - `createMarket` gUSD/RSS/@$50k King oracle
   - Deploy AMO + Exit
   - Mint eUSD → wrap → Landing gUSD → `supplyAmo` → gUSD idle
   - Peel RSS from eUSD book (LTV headroom at $50k) → post → borrow gUSD to HOT

## Fire

```bash
KING_GO=1 FIRE_IDLE=1 \
MINT_EUSD=100000000000000000000000000 \
MINT_GUSD_PATH=100000000000000000000000000 \
BORROW_BPS=7000 WRAP_BPS=9000 PEEL_RSS=100000000000000000000000 \
forge script script/FireSovereignIdleProduct.s.sol:FireSovereignIdleProduct \
  --rpc-url $BASE_RPC_URL --broadcast -vvv
```

## Addresses (fill after fire)

| Piece | Address |
|--|--|
| eUSD AMO (scaled) | `0x8960BdbE760E6C90c53a912063170a2Efb1df4Ed` |
| gUSD market ID | _pending_ |
| gUSD AMO | _pending_ |
| gUSD Exit | _pending_ |

Physics: gUSD = wrap(eUSD). Morpho idle ≠ wallet cash. Borrow pulls idle → HOT float.
