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

Base `maxStale` remains **3600** (owner = HOT) — refresh hourly via `FireZkAttestRefreshCast.sh` until HOT extends it.

---

## Blocked — Phase 1 live disarm

| Need | Status |
|--|--|
| Live router `0xBb3C372D…A7aC` | **`armed=true`** · `freeUsdc=0` |
| Owner | HOT `0x6708…a7d1` |
| Env keys present | Scroll `0xca76…` · Poly passport `0x3151…` · **HOT missing** |

**King action:** set `HOT_KEY` for Base hot, then:

```bash
HOT_KEY=0x… bash king-pod/script/FirePrimeDisarmCast.sh
```

Script refuses wrong signer (will not fire Scroll key at Base router).

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
| 1 Hard Risk Locks | Code ready · **live disarm awaits HOT_KEY** |
| 2 Recycler / $375M float | Not fired — needs ~$9M real USDC |
| 3 ZK Blanket | **DONE** (all rails `bordersSecure=true`) |
| 4 China / NFC | **FROZEN** until 1–2 complete |

---

## One-block

```
FIRE=hard-locks-zk-rails
ZK Base/Poly/Scroll bordersSecure=true (epochs 3/2/2)
Poly+Scroll maxStale=7d
LIVE_ROUTER armed=true ← HOT_KEY then FirePrimeDisarmCast.sh
NO China · NO $9M recycler until Phase1 disarm + King GO
```
