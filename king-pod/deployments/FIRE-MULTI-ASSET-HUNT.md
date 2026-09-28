# FIRE — Multi-Asset Hunt

**Mode:** FIRE · executed  
**Branch:** `cursor/freeze-multi-asset-hunt-4f7f`  
**Doctrine:** Gold vault untouched. Hunt earns to HOT. Loan ≠ sell RSS.

---

## Reality held

yRSS/PARK ~$220M @ 100% util stays collateral. Scoreboard = **HOT ETH / HOT cbBTC** (+ USDC if won).

## HuntRouter (already armed)

`0xc4c63f8CD4182452f665e338F87b4d31aeF04516` · killSwitch=**false** · gasSafe=HOT

### Targets allowlisted (Base DEX venues)

| Venue | Address | Tx |
|--|--|--|
| Aerodrome Router | `0xcF77a3Ba…4E43` | [`0x1d19b89c…7db7`](https://basescan.org/tx/0x1d19b89c94aed4e12791b5cdb639faf72c4471fe042308a51666df872a8f7db7) |
| Uni SwapRouter02 | `0x2626664c…e481` | [`0x6dbd8e9c…f218`](https://basescan.org/tx/0x6dbd8e9ccf0dba9f164d7d173abfd3d50da6a54078021b13428d0b5d6876f218) |
| Aero Router V2 | `0x6Cb442ac…Be3E` | [`0xa5f492d6…495a`](https://basescan.org/tx/0xa5f492d63871997c8732be6419efcb5fbd4c9de71ba893c2a03901ae68ba495a) |

### Bots armed (3)

| Bot | Address | setHunter tx |
|--|--|--|
| **Bot1** | [`0xE4900bfc…C2b2`](https://basescan.org/address/0xE4900bfc340eE083C113211A51d1207A518fC2b2) | [`0xe5eb361a…4d4c`](https://basescan.org/tx/0xe5eb361a9464bca4d026976cd5eccb880698b873bdcdd81872c091a43c314d4c) |
| **Bot2** | [`0xbf0f0984…2bd4`](https://basescan.org/address/0xbf0f0984ba685abace6218083bff56d2b7952bd4) | [`0x318dcd24…e501`](https://basescan.org/tx/0x318dcd24b05a08840f9019a8d08b70401deb716291ac39846db6ed961895e501) |
| **Bot3** | [`0x715B1165…C6d6`](https://basescan.org/address/0x715B1165B5d886e14fA7D4562e49549Bd6E8C6d6) | [`0x520d0ef6…c788`](https://basescan.org/tx/0x520d0ef635487004269467e1820b3eaef51b46f546da7e3f184b0fbbb19fc788) |

HOT remains hunter=true.

### Smoke pipes (Morpho 0-fee flash · empty path)

| Asset | Amt | Tx |
|--|--|--|
| WETH | 0.01 | [`0xbefd142b…23f5`](https://basescan.org/tx/0xbefd142b6b5cd150b5ac54a9be8ac358f6f09d94665b9ec3f35cf0b892c123f5) |
| cbBTC | 0.001 | [`0x46de74a1…9f1d`](https://basescan.org/tx/0x46de74a1a7d0ef2f52f22411ecf813d4c100ba3a30ad508224166126ae989f1d) |
| USDC | $1 | [`0x3da8eeb8…cf39`](https://basescan.org/tx/0x3da8eeb8f162bb68be0a81ba85f3869ba31085a5af319bee9bc526b75d5fcf39) |

Flash liquidity on Morpho: WETH deep · cbBTC deep · USDC ~$227M.

---

## Honest next (ops, not freeze theater)

Pipes are live. **Profit** needs edge calldata into allowlisted venues (liq / misprice). Bots expose `exec(token, assets, targets, values, datas, tip)`. Sweep → HOT.

Polygon: no HuntRouter/Morpho Blue twin here — Base is the flash rail. Cross-chain later if King funds poly hunter.

---

## One-block

```
FIRE=multi-asset-hunt
HUNT=0xc4c63f8C…4516 kill=false
BOTS=0xE490… · 0xbf0f… · 0x715B…
TARGETS=Aero+Uni+AeroV2
SMOKE=WETH+cbBTC+USDC ok
SCORE=HOT_ETH · HOT_cbBTC
GOLD=untouched
```
