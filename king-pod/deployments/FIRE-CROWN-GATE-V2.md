# FIRE — CrownGateV2 ZK adopt (Base)

**Mode:** FIRE · ZK mandatory · Base 8453  
**Commanded:** `ZK_SHIELD=1` · `BORROW_USDC=1_000_000` · `CROWN_CREDIT=100_000` · `LANDING=HOT` · gate `0x3fF6…7091`

---

## Preflight

| Check | Result |
|--|--|
| `isProven(HOT)` port WalletGate | **true** · thr $700k |
| Sovereign Morpho cash | **0** |
| ZK Credit USDC bal | **0** |
| Full borrow package | **`LIQUIDITY_SHORT`** (no broadcast of draws) |

yRSS book is ~100% utilized on legacy RSS; no free USDC to land 1.1M at HOT without external seed.

---

## Fired (ZK)

| Item | Address / value |
|--|--|
| **CrownGateV2** | [`0x76fa390951fA31185490378F46B6e9F05bA4bC3b`](https://basescan.org/address/0x76fa390951fA31185490378F46B6e9F05bA4bC3b) |
| **CrownZkAutoDraw** | [`0x1DF67E17176CD977B2f016a4eAa89e5598E4B345`](https://basescan.org/address/0x1DF67E17176CD977B2f016a4eAa89e5598E4B345) |
| zkGate | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` |
| Adopted RSS on gate | **222,521.94** |
| Gate borrow | **0** |
| yRSS sovereign cap | **$50M** enabled |
| PA sov maxIn/maxOut | **$5M** |

### Key txs

| Step | Tx |
|--|--|
| Deploy gate | [`0x999c382b…e31a`](https://basescan.org/tx/0x999c382ba299ff776bdac4ad122bd6541988be247e46b2c4a3341d35a832e31a) |
| Deploy AutoDraw | [`0xbe508907…5074`](https://basescan.org/tx/0xbe5089073c4d9b6a73e015f1538062413d5242083076fb6d3b800a44e4395074) |
| ZK `supplyCollateral` | [`0xd3ffd685…58c8`](https://basescan.org/tx/0xd3ffd68535dcaf611dee61d945e21c87fb7ab61467bea473f78a05c4993d58c8) |

`supplyCollateral` called `WalletGate.isProven(HOT)` → **true** before Morpho post.

---

## Not fired (liquidity)

| Commanded | Status |
|--|--|
| `BORROW_USDC=1,000,000` → HOT | **SKIPPED** — sovereign cash 0 |
| `CROWN_CREDIT=100,000` → HOT | **SKIPPED** — Credit bal 0 |

Next: seed **≥ $1,000,000** USDC into sovereign Morpho `0x1293…` and **≥ $100,000** into Credit `0x7527…`, then:

```
FIRE_CROWN_GATE_V2=1 ZK_SHIELD=1
GATE=0x76fa…  # or call AutoDraw.autoDraw directly
BORROW_USDC=1000000 CROWN_CREDIT=100000
```

(Use existing AutoDraw `0x1DF6…` — no redeploy required.)

```
ZK_SHIELD=1
IS_PROVEN=true
ADOPT=222521.94_RSS_ON_GATE
BORROW_USDC=BLOCKED_CASH_0
CROWN_CREDIT=BLOCKED_CASH_0
PA_SOV_MAX_IN=5e6
```
