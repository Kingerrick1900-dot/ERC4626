# HF + Self-Liq — live

## Self-liq ARMED
| Item | Address / Tx |
|--|--|
| `CrownElepanPreSelfLiq` | `0xeb99787FC3869aa2C1C5ABb9684A346Da34BAb90` |
| Morpho auth | true |
| `CrownMorphoZkPack` | `0x3e59CBFb9F37934E8ff797b83c53600d9d34e84C` |
| Deploy self-liq | `0x94ba4c743e86a515ebd3c93c2f40f4eae420331cd443a6eb29745a87d5080454` |
| Auth tx | `0x903b61620c0068ce1040b0190bf4c4d5faf3611cabb9b32f83e2834c291e9be7` |
| Pack deploy | `0x1b268d80efe6307231acc048aab57ddc39ef5f4fb7cdc76ecc48e4515614b183` |

Exit: `preSelfLiq.selfLiquidate()` or pack `selfLiquidateZk()` — flash repay → ELE/USDC surplus → Landing. ZK-gated.

## HF top-up
Target **2.00x** coll/debt needs **~5.85M Elepan** more on Morpho (now **20.15M** coll / **~$13.002M** debt → **~1.55x**).

Free Elepan sits on Landing. Hot has no `LANDING_KEY` in env.

```bash
# From Landing signer (or set LANDING_KEY), then:
KING_GO=1 FIRE_HF_SELF_LIQ=1 LANDING_KEY=$LANDING_KEY POST_ALL_LANDING_ELE=1 \
  forge script script/FireHfAndSelfLiq.s.sol:FireHfAndSelfLiq \
  --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --slow
```

Or Landing → Hot: transfer Elepan, then same fire without `LANDING_KEY` (posts hot balance).
