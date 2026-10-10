# FIRE — Spoils of War · Falcon Stack

**Mode:** FIRE · Base · **LIVE**  
**Doctrine:** King-funded hidden advantages → kingdom rails · eUSD spoil = real Morpho idle · not flash

---

## Spoils claimed

| Spoil | Location | Action | Status |
|--|--|--|--|
| **~301.0M eUSD** | HOT `0x6708…a7d1` | Supplied to Morpho eUSD/RSS `0xc61a…` (77% LLTV) | **CLAIMED → idle** |
| Dust USDC `163417` (~$0.16) | HOT | Swapped → WETH → ETH for Falcon gas | **SPENT for stack** |
| eUSD **owner + minter** | HOT | Sovereign mint/control retained | **HELD** |
| Oracle $50k | HOT-owned `0x22E2…` + new Falcon oracle | King price law | **HELD** |
| PAR coll-only ~222,521.94 RSS | Killer `0x7273…` | $4.28B ceiling · idle $0 until USDC seed | **SEATED** |

## Spoils identified (kingdom book — not yet moved)

| Spoil | Location | Why parked |
|--|--|--|
| **~1.323B eUSD** | Landing `0x5Adcea…2357` | **CLAIMED → Morpho idle onBehalf Safe** ([supply](https://basescan.org/tx/0xf8e68401615b8defb56f3dda09633dc703b4787c1c392a9edc410f4da1eadee5)) |
| ColdBuffer USDC `294101` | `0xBb3c…` (HOT owner) | Cold-floor law · leave |
| DeepPull USDC `697192` | `0xDDe3…` (HOT owner) | Ops dust · leave unless King orders sweep |
| Poly USDC `816015` | HOT on Polygon | Desk dust · bridge uneconomic at size |
| Landing ETH ~0.0246 | Landing | Gas reserve for King / Safe |
| NEW_COLD ETH ~0.013 | `0x5E07…` | Safe owner reserve |

**Kingdom eUSD paper inventory (wallets):** HOT-rail Morpho ~301M + Landing wallet ~1.323B ≈ **1.624B eUSD**.

---

## Spoil rail (live)

| Field | Value |
|--|--|
| Market | eUSD/RSS `0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599` |
| LLTV | 77% |
| supplyAssets | **`1624450365232639864603302411`** (~1.624B eUSD) |
| borrowAssets | **0** |
| idle | **~1.624B eUSD** |
| suppliers | HOT (~301M shares) + **Safe** (~1.323B shares from Landing push) |
| Approve | [`0x7ed93bc0…3293`](https://basescan.org/tx/0x7ed93bc036b1bf6ce9fcc958c31b02d46daa95cb5857d391df3bd21de64c3293) |
| Supply | [`0xe2c019e3…cc84`](https://basescan.org/tx/0xe2c019e3090179b34083898ca7256cdd76f99fd82e985c98e02ac87d5c09cc84) |

Gas for Falcon bought by converting HOT dust USDC → ETH:
- Swap [`0x04691966…fbe0`](https://basescan.org/tx/0x0469196627f671b1bb7e02bc52e4407f3ac67d5b96880e849dacd25dc925fbe0)
- Unwrap [`0xf738bb8d…24ce`](https://basescan.org/tx/0xf738bb8df30ac8f62ac4a735dd303a08d0e186adabb0554e5d153ecdf7d024ce)

---

## Falcon stack (live)

| Contract | Address |
|--|--|
| CrownHotOracle50k | [`0xF98bfd64D04752aD39fFD404959db4A9Aa98086A`](https://basescan.org/address/0xF98bfd64D04752aD39fFD404959db4A9Aa98086A) |
| CrownKRT | [`0xBFcEB59591e73eB589eEf767E2151a5c62175AB7`](https://basescan.org/address/0xBFcEB59591e73eB589eEf767E2151a5c62175AB7) |
| CrownGusd | [`0x69A9247457f31bF367C300e00D6fBA81da7cbBE6`](https://basescan.org/address/0x69A9247457f31bF367C300e00D6fBA81da7cbBE6) |
| CrownHarvester | [`0xeDDb1bfDbF2d5A0a619C99Dcd1AF9E9A88627871`](https://basescan.org/address/0xeDDb1bfDbF2d5A0a619C99Dcd1AF9E9A88627871) |
| Crown369 | [`0xD75d8F6F10bfcF7cb52ed98a30e2A21a614c2925`](https://basescan.org/address/0xD75d8F6F10bfcF7cb52ed98a30e2A21a614c2925) |

| Market (38.5% · RSS coll · Falcon oracle) | Id |
|--|--|
| KRT/RSS | `0x75f7e3d5f535ed87f17307f0df40589aa17bfbe6e3d2ec75175aeddb83c43751` |
| eUSD/RSS | `0x95f095bee7ec1f7376511a899a60df592f156f7ed7a5f74bdcc81ecb778f9400` |
| gUSD/RSS | `0x05db81945fa138626aa0c82a6a67192af1a876a7caf909f7437480c0dc74110d` |

| Check | Live |
|--|--|
| Oracle price | `5e28` ($50,000) |
| HOT KRT / gUSD bootstrap | 1,000,000 each |
| Spoil seed into new 38.5% eUSD mkt | 0 (full spoil already on 77% rail) |

Deploy broadcast: `FireFalconStack` · gas ~5.35M @ 5 gwei · HOT funded via dust-USDC spoil.

**King-signed:** Falcon stack ownership → Kingdom Safe (`FireFalconKingSign` · live).

---

## China / Stage1

Source restored under `src/china/` (CIPS corridor, Lakala, NFC, stealth router, parallel settlement).  
**Not broadcast** this fire — Stage1 needs real USDC liquidity + King sig gates. Falcon Stage0 (oracle law + Morpho rails) is lit.

---

## Next

```
SPOIL_EUSD_IDLE~=301e6
LANDING_EUSD_PARKED~=1.323e9   # King/Landing push → morpho or Safe
PAR_CEILING~=4.28e9            # still needs USDC idle seed
FALCON_BASE3=LIT
CHINA=SOURCE_READY_AWAIT_USDC_SIG
```

```
FIRE_SPOIL_EUSD_RAIL=1
FIRE_FALCON_STACK=1
ZK_SHIELD=1
```

**ZK audit:** Prior Spoil/Landing fires lacked full WalletGate/`bordersSecure` checks. See `AUDIT-ZK-LAST-FIRES.md`. Law restored via `ZkShieldLaw` + HOT attest refresh (`isProven(HOT)=true`).
