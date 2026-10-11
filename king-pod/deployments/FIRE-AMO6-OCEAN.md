# FIRE — AMO 6 Armor + Ocean External USDC Leg

**Mode:** FIRE · Base  
**Order:** AMO 6 → Spoils router → Ocean external USDC (Phase 3 first leg)  
**USDT / DAI / EURC:** not seeded yet — next widen after more USDC

---

## AMO 6 — green on-chain

**Proof paste (full txs · live canMint · borders ×3):** see [`PROOF-AMO6-GREEN.md`](PROOF-AMO6-GREEN.md).

| Piece | Address / value |
|--|--|
| **CrownCircuitBreaker** | `0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8` |
| armed / tripped | **true** / **false** |
| yRssBaseline | `255873051242331` |
| PauseStub (registered) | `0xBbA40146e15EFE9350b41d99BD067630135c683E` + 3 more (`FireAmo6RegisterMore`) |
| amoCount | **4** |
| **MintGate** | `0xf2a6cE82E89C347637e173Dd892385A118048982` |
| canMint / unlocked | **false** / **0** |
| ColdBuffer `minBufferBps` | **3000** |
| bordersSecure Base / Poly / Scroll | **true** · epochs **16 / 8 / 10** |
| PqRegistry keyCount | **4** (pre-existing) |

### Txs
| Step | Hash |
|--|--|
| setMinBufferBps(3000) | [`0x4e626ef5…5963`](https://basescan.org/tx/0x4e626ef50bc939d1e31caec215d911a6c84e1bebb9997f9b9cfc53a33b275963) |
| CircuitBreaker create | [`0x5ad54e05…20d2`](https://basescan.org/tx/0x5ad54e0534153c7229aa791f79b25eee0c78bf2e090e47e45d8cd70f4c5920d2) |
| MintGate create | [`0x159f6a82…7fac`](https://basescan.org/tx/0x159f6a82afb99796ee9228f3b1343c8880423603d1383894605831db0ac17fac) |
| PauseStub + registerAMO | [`0x5074bec9…3a08`](https://basescan.org/tx/0x5074bec9bbcc6482b8b871bd658f387105f4b09b456bc4b9f0628df453c33a08) · [`0x982eb578…3ece`](https://basescan.org/tx/0x982eb5788e9d4ef7e021bf00ed49e5e99a14997ef63068681fb95bfe3e5e3ece) |

---

## Spoils router — live

| | |
|--|--|
| **CrownSpoilsOfWar** | `0x4dBc59786790F3B7B6aB03730dD2Db7DC7feecd0` |
| Split | 30% Cold / 50% Ocean / 20% HOT |
| oceanExternal | DeepPull `0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A` |
| Deploy tx | [`0x0449da6b…1010`](https://basescan.org/tx/0x0449da6bdef5c0d8af42de43cc6df112816cf9356dd475211f2a6e5638c71010) |

---

## Ocean external USDC leg — seeded

| | |
|--|--|
| Venue | DeepPull Uni eUSD/USDC fee 500 `0x96D0022c…a666` |
| USDC seeded | **686232** (6dp) — all HOT USDC |
| eUSD minted into LP | `686232e12` wei |
| LP tokenId | **6136635** |
| Seed tx | [`0xe8b9e0da…6e07`](https://basescan.org/tx/0xe8b9e0da4771980d0a7d09df61b34309a0b191db19f00dfaebbe8e40a9d96e07) |

### Scoreboard (numbers)

| Meter | Value |
|--|--:|
| HOT USDC Base | **2** |
| HOT USDC Polygon | **816015** |
| ColdBuffer USDC | **294101** |
| ColdBuffer bps | **3000** |
| Ocean pool USDC | **17527** |
| MintGate.canMint | **false** |
| Breaker.armed / amoCount | **true** / **4** |
| Spoils proved | **DUST_UNI** (7) |

See `FIRE-COMPLETE.md` for attest + Poly Credit + stub txs.

---

## Not yet

- USDT · DAI · EURC Ocean legs (widen when more external USDC arrives)  
- Material Spoils campaigns (router + first dust campaign live; needs TWAMM/fee fills)  
- AMO 1–5 real targets (4 pause stubs registered)  

```
AMO6=GREEN
AMO_COUNT=4
SPOILS=0x4dBc59786790F3B7B6aB03730dD2Db7DC7feecd0
OCEAN_USDC_LEG=SEEDED
FIRE_COMPLETE=1
NEXT=TWAMM_fills→widen_USDT_DAI_EURC
```
