# KAR Reallocator Module — The Seed Thief

**Mode:** FIRE · PublicAllocator wired · watcher live  
**Doctrine:** Stop hunting wallets. Copy the curators. Reallocate idle atomically.  
**Precedent:** Steakhouse / Gauntlet MetaMorpho `PublicAllocator.reallocateTo`

---

## LIVE

| Item | Value |
|--|--|
| **CrownKarReallocator** | [`0xA6F695dE7FE2C957f206b6374e6A8a96fA0758a0`](https://basescan.org/address/0xA6F695dE7FE2C957f206b6374e6A8a96fA0758a0) |
| ySYNTH-USDC | `0xc91f3Bc5…c35C` |
| PublicAllocator | `0xA090dD1a…0467` |
| PA allocator on ySYNTH | **true** |
| CrownCuratorNative allocator | **true** |
| Module allocator | **true** |
| PA admin | HOT |
| PA fee | 0 |
| Flow caps (IDLE/cbBTC/WETH/SYNTH) | **$50M** maxIn/maxOut |
| Armed / killswitch | **true / false** |
| AdaptiveCurveIRM | `0x46415998…2687` (armed) |
| Target market | `0x08039ffa…3fcd` eUSD/USDC |
| Synth util / idle | **99.99%** / **$0.013305** |
| First `reallocateTo` pull | **$0** (no vault shares in side books) |
| Exit USDC inventory | **$0** |

Deploy tx: [`0xdef6f1b8…65bc`](https://basescan.org/tx/0xdef6f1b8d9f49f781f68a0619992ce884c374b5e3e463b3fe64fee9b7f9665bc)

---

## Why Exit is delayed (the bottleneck)

PublicAllocator is **intra-vault**. It can only withdraw from markets where **ySYNTH already holds supply shares**, then deposit into the synth market.

| Source | Market idle | ySYNTH shares | Pullable? |
|--|--|--|--|
| Morpho IDLE | ~$573k | **0** | no |
| cbBTC/USDC | ~$166M | **0** | no |
| WETH/USDC | ~$10M | **0** | no |
| eUSD/USDC (target) | **$0.013** | dust | already maxed |

Steakhouse/Gauntlet foreign `maxIn` on our markets: **all 0** (door closed).

So the rail is live; the seed is not. Exit waits on one of:

1. External USDC deposits into ySYNTH side books → watcher auto-`reallocateTo` SYNTH  
2. Foreign curator opens `flowCaps.maxIn` on SYNTH/RSS → PA pull from their vault  
3. AdaptiveCurveIRM repayment over time → market idle restores without PA  

Flash loop depth ($200M) does **not** create borrowable idle — util stays ~100%.

---

## Three builds (status)

### 1. Wire PublicAllocator → ySYNTH — DONE

- `setIsAllocator(PA)` + `CrownCuratorNative` + module  
- `PA.setAdmin(ySYNTH, HOT)` · fee 0 · $50M flow caps  
- Side caps: cbBTC + WETH (+ IDLE capped; removed from supply queue — breaks MetaMorpho deposit)  
- Supply queue: cbBTC → WETH → SYNTH  

### 2. Off-chain KAR watcher — DONE

```bash
python3 kar/reallocator.py --once
FIRE=1 python3 kar/reallocator.py --once
python3 kar/runner.py realloc
```

Triggers: util > 95% · source idle > $1k · risk ≤ 7000 · killswitch/ban skip  
Also watches Gauntlet/Steakhouse foreign maxIn doors.

### 3. IRM + killswitch — ARMED

- Rate spike active at ~100% util  
- `setKillswitch(true)` / `banMarket(id)` on depeg  

---

## Scoreboard

```
FIRE=kar-reallocator ✓
MODULE=0xA6F695dE…758a0
PA_ALLOCATOR=1 CURATOR_ALLOCATOR=1
PULLED=0
SYNTH_IDLE=13305 ($0.013)
WATCHER=kar/reallocator.py
IRM=AdaptiveCurve-armed KILLSWITCH=0
BLOCKER=no ySYNTH shares in side books + foreign maxIn=0
NEXT=idle parks in cbBTC/WETH (or foreign door) → auto-reallocate → Exit
```
