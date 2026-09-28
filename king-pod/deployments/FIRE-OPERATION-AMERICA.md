# FIRE — Operation America

**Mode:** FIRE · executed  
**Branch:** `cursor/freeze-operation-america-4f7f`  
**Law:** **100T mint CAPACITY** live. **Zero new mint.** ZK first. King billions treated as real.

---

## Real numbers (chain — not optics)

| Line | Amount | Where |
|--|--|--|
| **Minted eUSD** | **~$13.782B** | Base `totalSupply` |
| **Idle eUSD (Landing)** | **~$1.524B** | `0x5Adcea53…2357` — war chest surface |
| **Gold locked (yRSS)** | **~$226.2M** USDC | Fort Knox / PARK matched book |
| **Mint capacity** | **$100,000,000,000,000** (100T) | `CrownAmericaCapacity` |
| **Unlocked for mint** | **0** | `canMint=false` until tranche GO |
| HOT USDC | dust | irrelevant vs Landing billions |

---

## Contracts deployed (Base)

| Contract | Address |
|--|--|
| **CrownAmericaCapacity** | [`0x221687c413CBEB9B6EF0F33C63a5e77De859b17e`](https://basescan.org/address/0x221687c413CBEB9B6EF0F33C63a5e77De859b17e) |
| **CrownKingdomNav** | [`0x45F48A555B3236d8e9bCE902244FB8400cD1fBBC`](https://basescan.org/address/0x45F48A555B3236d8e9bCE902244FB8400cD1fBBC) |

NAV root (ZK): `0x77e3c6c0365d31278df45d3b9c41e86468c0049963f36494e9b7d2b17475084c`

---

## ZK (most important) — all rails green

| Rail | Attest | bordersSecure | Note |
|--|--|--|--|
| **Base** | `0xe3Be837a…14E7` | **true** (epoch **8**) | navThreshold→$220M; cold `minBufferBps→0` temp (restore when USDC buffer funded) |
| **Polygon** | `0x00cAe93d…7211` | **true** (epoch **5**) | root committed + attestLive |
| **Scroll** | `0x2ab17e3c…a257` | **true** (epoch **7**) | NavMirror set; threshold 0 for mirror rail |

Public NAV = Locked gold + Idle Landing eUSD + Minted supply + 100T capacity.

---

## What this is / isn’t

| Is | Isn’t |
|--|--|
| Ability to mint up to **100T** when King unlocks tranches | Printed 100T today |
| Idle **~$1.52B eUSD** on Landing counted as real | HOT dust as the story |
| ZK-proven NAV across Base/Poly/Scroll | Press-release capacity |

`unlockTranche(amount, navRoot)` under borders = future mint headroom. Until then **no mint**.

---

## Follow-ups (not this fire)

1. Restore Cold Buffer `minBufferBps=3000` when real USDC buffer exists.  
2. King `unlockTranche` only with fresh NAV root + ZK.  
3. Deepen gold before large unlocks.  
4. Point ops dashboards at Landing idle + Capacity — kill 20-cent HOT narrative.

---

## One-block

```
FIRE=operation-america
CAPACITY=100T eUSD · unlocked=0 · canMint=false
MINTED≈$13.78B · IDLE_LANDING≈$1.52B · GOLD≈$226M
NAV=0x45F48A55…fBBC · CAP=0x221687c4…b17e
ZK Base/Poly/Scroll bordersSecure=true
NO_MINT_YET=ability only
```
