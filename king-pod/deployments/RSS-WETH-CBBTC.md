# RSS/WETH + RSS/cbBTC — Fat Morpho Whale Seed (LIVE)

**Fired:** Base · Morpho Blue · flash from Morpho inventory (~75k WETH / ~36k cbBTC)  
**LLTV:** 77% (nearest enabled to 75%; 70/75 not enabled)

## Live addresses

| Piece | Address |
|-------|---------|
| Oracle RSS/WETH | `0x3BB87B8ef3Df289C82540F89DE3e4f7762Ed4A98` |
| Oracle RSS/cbBTC | `0x7c60830200D14F7cDd020bd1c0Aa10d6F254bd0b` |
| CrownFatFlashSeed | `0x38bF10f1b62282F08f9fC97E2DB116DD2cBbf2F6` |
| Market RSS/WETH | `0x6d0c2531ad3078b19f569d3d9b48fb9348682a1b769f726c4196e6091a3c35e9` |
| Market RSS/cbBTC | `0x88fb488074c9f9f3acaa5f84a2f4181bc371defa66ff4a9e42e1e5f0d563be0e` |

## Book state (live)

| Market | Supply | Borrow |
|--------|--------|--------|
| RSS/WETH | **10 WETH** | **10 WETH** |
| RSS/cbBTC | **5.5 cbBTC** | **5.5 cbBTC** (~\$365k) |

HF_raw (post 5 cbBTC tranche): WETH **1.56** · cbBTC **1.56** (floor 1.55 OK; alert band &lt;1.60).

cbBTC tranche tx: `0x04ccccdf5f7b799e50f8493e6ca521044503c2a829dbffcaf6bff0bb0f0850ad`  
Script: `FireCbtcTranche.s.sol` (KING_OK + FIRE_CBTC_TRANCHE).

## Tx hashes

| Step | Hash |
|------|------|
| Oracle WETH | `0x7f03e8360af53ff49c3d30062d7bee99c7bc02ebc4fd9510d1ea89bde14bf536` |
| Oracle cbBTC | `0x2d3221f0dd846d737b63a433032a80b6c57a7661c4e62aa836e9276e9c4b3f37` |
| createMarket WETH | `0xb77592c64d0e229b2dbdfd8711964d88a64f03be421a3143b17cd0428147d0b3` |
| createMarket cbBTC | `0x5009edfac4f64c44215dab51a6437a5cccc4fa2b61d5e4fc6e6be03ed32a2e67` |
| CrownFatFlashSeed | `0x465d2462cd43aab368024d5ab0255726b9f516e07e0e3f1d4cdc9dc919c48f96` |
| **First flash borrow (WETH seed)** | **`0xe51c25da485f339b1947f86cb5c7fcfafcb58c2cde8f8f3592ba08aab0519a97`** |
| Second flash borrow (cbBTC seed) | `0xdf6836c280503fa477ece16a2876bbd14f54860d0a47d9a178445ff7ab1d1f50` |

## What fired

1. Opened RSS→WETH and RSS→cbBTC Morpho markets (Fixed $1 RSS × fat Uni TWAP loan/USDC).
2. Flash-seeded from **Morpho** WETH/cbBTC holdings (not Aero dust).
3. Supply + borrow matched on both books — real depth opened.

## Scale next

```bash
# Upsize flash seed (needs RSS collateral headroom + gas)
KING_OK=1 FIRE_FAT_SEED=1 FLASH_WETH=100ether FLASH_CBTC=5e8 \
  forge script script/FireFatRssWethCbbtc.s.sol:FireFatRssWethCbbtc --rpc-url $BASE_RPC --broadcast
```

Or call `CrownFatFlashSeed.flashSeed` on existing markets with larger `FLASH_*`.

TWAP pools (fat): WETH/USDC `0xd0b5…F224` · cbBTC/USDC `0xfBB6…43ef`


## HF guard (locked)

`CrownFatFlashSeed` reverts if HF_raw < **1.55**. Emits `HfAlert` if < **1.60**. Monitor: `script/hf_monitor_rss_weth_cbbtc.sh`.
