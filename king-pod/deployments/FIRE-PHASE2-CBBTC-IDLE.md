# FIRE — Phase 2 cbBTC idle path (fork SUCCESS)

**Mode:** PHASE 2 · Base fork · King's command  
**Market:** `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836`  
**Gate:** AMO 6 green (armed, not tripped) · Phase 1 verify published  
**Live broadcast:** not this file — fork proof only

---

## What fired on fork

| Test | Result |
|--|--|
| Borrow **$5M** USDC vs cbBTC coll → HOT | **PASS** |
| Borrow **$25M** → Spoils 30/50/20 → Cold + DeepPull Ocean + HOT | **PASS** |

```bash
forge test --match-contract SimCbBtcIdlePhase2Test -vv --fork-url $BASE_RPC_URL
```

### $5M borrow

| Meter | Value |
|--|--:|
| Idle before | ~$168,136,202 |
| HOT USDC delta | **+$5,000,000** |
| Idle after | ~$163,136,202 |

### $25M + Spoils Ocean

| Leg | Amount |
|--|--:|
| Spoil total | **$25,000,000** |
| Cold 30% | **$7,500,000** |
| Ocean (DeepPull) 50% | **$12,500,000** |
| HOT 20% | **$5,000,000** |

---

## Machine proven

1. Verified idle on Morpho cbBTC/USDC is borrowable.  
2. King path: post cbBTC → borrow USDC → HOT.  
3. Sealed Spoils router feeds Cold + Ocean USDC sink without bypassing AMO 6.  
4. USDT / DAI / EURC still need their own inventory after USDC lands.

---

## Phase 3 (live) — awaits King's word only

Requires **real cbBTC** (or foreign PA) on HOT. Fork used `deal(cbBTC)` for collateral sizing under 86% LLTV.

```
PHASE2=PASS
MARKET=0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836
BORROW_5M=PASS
BORROW_25M_SPOILS=PASS
AMO6=GREEN
PHASE3=AWAIT_KING_WORD
```
