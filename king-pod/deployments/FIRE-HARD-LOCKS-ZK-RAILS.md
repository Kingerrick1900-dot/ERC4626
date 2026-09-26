# FIRE — Hard locks + ZK rails (above call of duty)

**Mode:** FIRE · Phase 3 ZK **done** · Phase 1 live disarm **DONE**  
**Decree:** Fire go — secure before China sequence, max effort.  
**Branch:** `cursor/fire-hard-locks-zk-rails-4f7f`

---

## Executed (live)

### Phase 3 — ZK blanket refresh

`attestLive(0x0)` — permissionless; fired with Scroll / Poly keys.

| Rail | Attest | Tx | Epoch | `bordersSecure` |
|--|--|--|--|--|
| **Base** | `0xe3Be837a…14E7` | [`0x5869e0c5…2273`](https://basescan.org/tx/0x5869e0c56c4816e4328a43968cebc59dc408e909ae6056bbfb8adcf2cc172273) | **3** | **true** |
| **Polygon** | `0x00cAe93d…7211` | [`0xdcc89192…3a8c`](https://polygonscan.com/tx/0xdcc891928046f517c582dd194db505910bdcdb93dc1ea455591c6eb58fb03a8c) | **2** | **true** |
| **Scroll** | `0x2ab17e3c…a257` | [`0xdd63ded6…ff18`](https://scrollscan.com/tx/0xdd63ded61faac035328c392ae6423ac69a8a2506689c8548a06f3d28d073ff18) | **2** | **true** |

### Above duty — extend stale window (Poly + Scroll)

`setThresholds(nav, redeemableWindow, maxStale=7d)` — owner keys we hold.

| Rail | Tx | `maxStale` |
|--|--|--|
| Polygon | [`0x1cb6498d…1f29`](https://polygonscan.com/tx/0x1cb6498df441a3b313cbbb5e75d99181706fdfd8dd810c8edff964e185751f29) | **604800** (7d) |
| Scroll | [`0x42013cf0…0f26`](https://scrollscan.com/tx/0x42013cf0a2cd4d863a126ea75d0444313f6dc080344ce405a3d067e954750f26) | **604800** (7d) |

Base `maxStale` now **604800** (7d) — HOT one-time fire.

---

## Phase 1 live disarm — DONE

| Action | Tx | Result |
|--|--|--|
| `setArmed(false)` live router `0xBb3C372D…A7aC` | [`0xceccfaf3…3459`](https://basescan.org/tx/0xceccfaf3ff8c712aa97e5e095eb1333956242aa9a52bf3abdfbe653d37943459) | **`armed=false`** |
| Base `setThresholds(…, maxStale=7d)` | [`0x98f69593…01a0`](https://basescan.org/tx/0x98f69593746dea5ea7311ec9a5e309bc1af8d88c3bc46702a9e8abfca8ac01a0) | **604800** |
| Base `attestLive` | [`0xdf2ecc45…b524`](https://basescan.org/tx/0xdf2ecc45ebc4a57d75f7608a0ef1741a2b2d92f2b04365304b43bd17a8b8b524) | epoch **4** · borders **true** |

**Issue that blocked earlier:** env only had Scroll (`0xca76…`) + Poly passport (`0x3151…`). Router/attest owner is HOT `0x6708…` — one-time HOT key supplied by King, used, **not stored in repo**. **Rotate HOT.**

---

## Shipped hard-lock code (next deploy / HOT GO)

| Patch | Lock |
|--|--|
| `USDCBorrowRouter.setArmed(true)` | Reverts `IdleBeforeArm` if `freeUsdc()==0` |
| `SelfRepayingTreasury.freezeCredit()` | Irreversible credit pointer freeze |
| `SelfRepayingTreasury.setPaused` | Pause sweep / pokeRepay |
| `pullSurplus` | Always pays **King only** |

Live contracts are the prior deploy — these patches arm the **next** router/treasury upgrade after King names deploy GO. Immediate live risk reduced by **disarm** (HOT) + ZK borders (done).

---

## Sequence status vs freeze law

| Phase | Status |
|--|--|
| 1 Hard Risk Locks | **Live disarm DONE** · patched sources for next upgrade |
| 2 Recycler / $375M float | Not fired — needs ~$9M real USDC |
| 3 ZK Blanket | **DONE** (all rails `bordersSecure=true`, maxStale 7d) |
| 4 China / NFC | **FROZEN** until Phase 2 complete |

---

## One-block

```
FIRE=hard-locks-zk-rails
ZK Base/Poly/Scroll bordersSecure=true · maxStale=7d
LIVE_ROUTER 0xBb3C…A7aC armed=false ✓
ROTATE HOT — one-time key was chat-pasted
NO China · Phase2 recycler awaits ~$9M USDC + KING_GO
```
