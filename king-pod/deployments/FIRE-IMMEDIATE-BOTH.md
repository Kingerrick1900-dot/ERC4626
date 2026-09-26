# FIRE — Immediate Both (Phase I + II)

**Mode:** FIRE · executed · no solver wait  
**Branch:** `cursor/fire-immediate-both-4f7f`  
**Doctrine:** Hunt armed · flash delever proven · Royal Card live · ZK refreshed.

---

## Phase I — Harden & Hunt Arm

| Action | Tx | Result |
|--|--|--|
| `setGasSafe(HOT)` | [`0x61e1cdd2…a757`](https://basescan.org/tx/0x61e1cdd24408cb46b85f46759bde83b010b403d7f3e3c575ae3ac2a5b7eba757) | gasSafe = HOT |
| `setHunter(HOT, true)` | [`0x18b11d77…8563`](https://basescan.org/tx/0x18b11d779f82111b1944f4d3cb09fb70f856fa72f2f3b618ddb8807e21a68563) | hunter = true |
| `setKillSwitch(false)` | [`0xb40d4594…8076`](https://basescan.org/tx/0xb40d459484d8616b4c872292eb4148aef7541d5455a84c95cbe391768eb38076) | **killSwitch = false** |
| Base `attestLive` | [`0x95de5d35…1ef5`](https://basescan.org/tx/0x95de5d358a0e6544b3d7a4b2547471015b8eb21654a8c1efc82b2035b9761ef5) | borders **true** |
| Polygon `attestLive` | [`0xba0a19e8…6707`](https://polygonscan.com/tx/0xba0a19e89da1d5979a342d9427f3c3328c7e9efdc13d8c5a7782a0063d6d6707) | epoch **3** · borders **true** |
| Scroll `attestLive` | [`0x455a47e1…b7a3`](https://scrollscan.com/tx/0x455a47e160d184d0baecb0730f5795d859b35a56e56239031c8ad9f67dcfb7a3) | epoch **3** · borders **true** |

HuntRouter `0xc4c63f8C…4516` — **ARMED**. Register `targetOk` before live `hunt()` calls.

---

## Phase II — Royal Card + Flash Delever

| Action | Address / Tx | Result |
|--|--|--|
| **RoyalCard** deploy | [`0xcE228F10…A85c`](https://basescan.org/address/0xcE228F101D4884Ee29f00B8f2BFF1B66D9DDA85c) · [`0x12d6bfc6…cd9f`](https://basescan.org/tx/0x12d6bfc6981e6f517a797c68497816d07eac802fd11f922dc39b89f822dbcd9f) | LIVE |
| `setModules(0, attest)` | [`0x6b479bf0…b409`](https://basescan.org/tx/0x6b479bf0e1e444def6680211b7f9866d104d8a3de7cb242eccddba32a38cb409) | borders gate wired |
| **CrownFlashParkDelever** | [`0xcc34D424…d0A2`](https://basescan.org/address/0xcc34D42486dDB85E60a9dC2016D2513614cEd0A2) · [`0x57faddb2…e98c`](https://basescan.org/tx/0x57faddb2723490a2ad2f8dacc8c82fa89535fb317ae31c4ba81ad28c2fc3e98c) | LIVE (approve-0 fix) |
| Smoke delever **$1,000** | [`0xd34853f2…9b46`](https://basescan.org/tx/0xd34853f2069ec049c2f89088a78de90acb30e99e8cc4cf46cb9dafcd70979b46) | success |
| **Delever $9,000,000** | [`0x70393b9e…8ea8`](https://basescan.org/tx/0x70393b9eedbd5c05f5b6def32e43da96ae218f4ad6013e329050e42ccbe08ea8) | success |

### Post-$9M delever (honest)

| Metric | After |
|--|--|
| PARK supply ≈ borrow | **~$220.63M** (was ~$229.6M) |
| HOT borrow shares | reduced (debt **−$9M**) |
| yRSS `totalAssets` | **~$220.63M** |
| HOT USDC | **1 wei** (Δ≈0 — delever, not war chest) |
| Util | still ~**100%** (supply and borrow both fell) |

---

## Still true

- 7683 inbound order `0xf6479468…d825` still open (bonus if filled)  
- Hunt needs allowlisted **targets** before bots call `hunt()`  
- Royal Card: issue cards + NFC hardware = Phase 4 manufacturing  
- **Rotate HOT** when King closes this fire window  

---

## One-block

```
FIRE=immediate-both
HUNT killSwitch=false · hunter HOT=true
RoyalCard=0xcE228F10…A85c
FlashDelever=0xcc34D424…d0A2
DELEVER_$9M=0x70393b9e…8ea8 · PARK/yRSS ~$220.6M · HOT USDC still ~0
ZK Base/Poly/Scroll bordersSecure=true · maxStale=7d
ROTATE HOT after ops
```
