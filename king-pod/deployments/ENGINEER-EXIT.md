# FireEngineerExit — DeepSeek draft → kingdom-correct

## Draft errors (do not broadcast as written)

| Draft | Live Morpho / MetaMorpho |
|--|--|
| `yELE.setMaxIn(token, …)` | **Does not exist.** Caps = `PA.setFlowCaps(vault, FlowCapsConfig[])` |
| Oracle `1.50e18` | Wrong scale. ELE/USDC Morpho `$1` = **`1e34`**; `$1.50` = **`1.5e34`** |
| `supplyCollateral(..., receiver)` | 4th arg is **`bytes data`**, not receiver |
| Withdraw **all** Morpho ELE while **~$50M debt** on 77% market | Reverts / liquidates the engine. Move **free** ELE only |
| `borrow(700k)` on brand-new market | New book idle = **0** → revert. Borrow **idle only** |
| USDC → deployer | Kingdom path → **Landing** |

## What the corrected script does

`script/FireEngineerExit.s.sol` + `src/CrownFixedOracle.sol`

1. PA flow caps `$700k` on kingdom vault `yELE-K` `0x0D96…9532`  
2. Deploy `CrownFixedOracle` (default `$1.50` Morpho-scale)  
3. `createMarket` ELE/USDC **91.5%** LLTV  
4. Supply **free** hot ELE as collateral  
5. Borrow **liquid idle** → Landing (0 if book empty — no fake 700k)

```bash
KING_GO=1 FIRE_ENGINEER_EXIT=1 \
forge script script/FireEngineerExit.s.sol:FireEngineerExit \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

## Already live (no wait)

| | |
|--|--|
| `yELE-K` | `0x0D96ba80502Eb8A08A6d3bd4680134b20C229532` timelock **0** |
| WETH + ELE caps | **$50M** each — enabled |
| Create tx | `0xc107ce74…24103c` |

Headroom on 91.5% + free ELE is the nation’s extra borrow **capacity**. Capacity earns when the book has cash — we build the market ourselves; we do not wait on Gauntlet’s calendar to **create** it.
