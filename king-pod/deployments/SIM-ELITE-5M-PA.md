# SIM — Elite $5M yRSS PA cap (never used live)

**Mode:** FORK SIM · Base  
**Door:** Public Allocator `flowCaps.maxIn = 5_000_000e6` on yRSS → RSS books  
**Status:** **PROVED on fork** · never broadcast live

---

## What elite engineering built

| Cap | Market | maxIn | maxOut |
|--|--|--:|--:|
| RSS / $1 oracle | `0x40ac09f3…b794` | **$5,000,000** | **$5,000,000** |
| RSS / $1200 oracle | `0x41c08085…7d88` | **$5,000,000** | **$5,000,000** |
| Idle buffer | `0x38c84619…2abb` | $50,000,000 | $50,000,000 |

PA: `0xA090dD1a701408Df1d4d0B85b716c87565f90467`  
Vault: yRSS `0xF80C0529bD94C773844E459853CD91B9263dD525`  
Admin: HOT (King)

These caps are a **spendable flow budget**. Using `$5M` of `maxIn` burns that side to `0` until the King resets caps.

---

## Simulation path (fork)

```
1. Seed $5M USDC into yRSS via idle market (queue idle-first)
2. PA.reallocateTo(yRSS, withdraw $5M from idle, supply RSS/$1)   ← uses elite maxIn
3. Post RSS collateral @ $1 oracle
4. Morpho.borrow($5M) → HOT
```

Test: `test/SimElite5mPa.t.sol`  
Run:

```bash
forge test --match-test test_elite_5m_pa_cap_unused_path -vvv --fork-url $BASE_RPC_URL
```

### Fork result (PASS)

| Meter | Value |
|--|--:|
| RSS1 idle before PA | 691 |
| RSS1 idle after PA | **5,000,000,000,691** |
| Borrowed to HOT | **5,000,000e6** |
| HOT USDC after | **5,000,000e6** |
| maxIn RSS1 after | **0** (full $5M inflow budget spent) |
| maxOut RSS1 after | **10,000,000e6** (5M base + 5M inflow credit) |

---

## Live fire requirements

1. Real USDC on yRSS in a market with `maxOut ≥ ask` (idle / cbBTC / WETH), **or** foreign vault PA into yRSS.  
2. Permissionless `PA.reallocateTo` for the pull into RSS.  
3. RSS collateral + HF headroom to borrow the new idle.  
4. King resets `setFlowCaps` after spend if another $5M window is wanted.

```
ELITE_5M_PA=SIM_PASS
MAXIN_BUDGET=5000000000000
PATH=idle→PA→RSS1→borrow→HOT
LIVE=NOT_FIRED
NEXT=seed_real_USDC_on_yRSS_idle_or_foreign_PA
```
