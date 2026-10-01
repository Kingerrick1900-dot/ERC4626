# KAR Reallocator Module — The Seed Thief

**Mode:** FIRE · PublicAllocator wire + off-chain watcher  
**Doctrine:** Stop hunting wallets. Copy the curators. Reallocate idle atomically.  
**Precedent:** Steakhouse / Gauntlet MetaMorpho `PublicAllocator.reallocateTo`

---

## The mechanism

PublicAllocator (`0xA090dD1a…0467` on Base) moves USDC **inside one MetaMorpho vault** between markets in a single tx:

```
reallocateTo(vault, [withdraw Market A …], supply Market B)
```

It cannot steal Steakhouse’s books unless **their** vault sets `flowCaps.maxIn` on the Kingdom market.  
Kingdom copy: wire PA on **ySYNTH-USDC**, multi-cap idle/bluechip books, KAR watches 24/7, fire when idle appears.

---

## Three builds

### 1. Wire PublicAllocator → ySYNTH

| Step | Action |
|--|--|
| Allocators | `setIsAllocator(PA)`, `setIsAllocator(CrownCuratorNative)`, Landing, module |
| PA admin | `PA.setAdmin(ySYNTH, HOT)` · `setFee(0)` |
| Flow caps | IDLE + cbBTC + WETH + SYNTH · maxIn/maxOut **$50M** |
| Side caps | Cap IDLE / cbBTC / WETH on ySYNTH · supply queue park→synth |
| Module | `CrownKarReallocator` armed · killswitch off · risk scores set |

Script: `script/FireKarReallocator.s.sol`

### 2. Off-chain KAR watcher

```bash
python3 kar/reallocator.py --once          # dry scan
FIRE=1 python3 kar/reallocator.py --once   # broadcast when triggered
python3 kar/runner.py realloc              # same via runner
```

| Trigger | Default |
|--|--|
| ySYNTH util | **> 95%** |
| Source idle | **> $1,000** |
| Risk score | **≤ 7000** |
| Killswitch | skip + log |
| Foreign maxIn | Steakhouse/Gauntlet door watch |

### 3. AdaptiveCurveIRM + killswitch

- IRM `0x46415998…2687` already on synth market — 4× rate spike at high util forces repay → idle restores over time.
- `CrownKarReallocator.setKillswitch(true)` / `banMarket(id)` stops pulls from compromised/depeg books.

---

## Honest constraint (scoreboard)

PA is **intra-vault**. ySYNTH today has dust TVL and **no supply shares** in side markets, so the first `reallocateTo` has nothing to withdraw.  
Wire + watcher are live so the moment idle parks in IDLE/cbBTC/WETH (or foreign maxIn opens), KAR pulls → SYNTH → Exit can draw real USDC.

| Fact | Value |
|--|--|
| ySYNTH | `0xc91f3Bc5…c35C` |
| Target market | `0x08039ffa…3fcd` eUSD/USDC |
| PA | `0xA090dD1a…0467` |
| CrownCuratorNative | `0x8Cb11A67…7558` |
| CrownExitNative | `0x97bd6846…bB68` |

---

## Scoreboard template

```
FIRE=kar-reallocator
PA_ALLOCATOR=1
CURATOR_ALLOCATOR=1
MODULE=<CrownKarReallocator>
PULLED=<usdc6dp>
SYNTH_IDLE=<usdc6dp>
WATCHER=kar/reallocator.py
IRM=AdaptiveCurve-armed
KILLSWITCH=0
NEXT=idle-in-side-books → auto-reallocate → Exit
```
