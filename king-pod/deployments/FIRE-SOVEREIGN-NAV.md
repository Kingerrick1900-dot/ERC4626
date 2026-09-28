# FIRE — Three-Number NAV Dashboard

**Mode:** FIRE complete · silent  
**Branch:** `cursor/fire-sovereign-nav-dash-4f7f`  
**Doctrine:** ZK-attested only. **No capacity. No potential.**

Tests: `SovereignNavTest` **2/2 PASS**

---

## Live (Base)

| Surface | Address |
|--|--|
| **CrownSovereignBoard** | [`0x4A8D5ac627D0fA1897DA3962a72EbE214Cba6E1F`](https://basescan.org/address/0x4A8D5ac627D0fA1897DA3962a72EbE214Cba6E1F) |
| CrownZkAttest | `0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7` |
| Board root | `0x3fce0b83a9567f2197d9f781b1cb5026c17f7a54e8e11bd8beefa605a216a049` |
| Attest epoch | **10** · `bordersSecure=true` · payload `0x96bd79a1…50b2` |
| Dashboard | `king-pod/dashboard/index.html` |

---

## Three rails (published)

| Rail | Numbers (chain) |
|--|--|
| **yRSS Gold** | Locked **~$226.6M** · Idle Real **~$1.524B** · Minted **~$13.782B** |
| **Ocean** | eUSD **$5.00B** · gUSD **$5.00B** · Depth **$10.00B** (Aero `0x8C009d…`) |
| **Landing** | Idle eUSD **~$1.524B** · Payroll **Live** · Cold **Seeded** ($2.66) |

Handoff “~$6B / ~$11B” ocean → **corrected to pool reserves 5B/5B/10B**.

---

## Wire path

1. Board `publish()` snapshots rails → root  
2. HOT `commitPayrollRoot(root,true)` + `attestLive(root)` → epoch 10  
3. Board `recordWire(10)` stores payload · `rootWired=true`  
4. Dashboard reads live rails + links each number to Basescan / attest proof  

---

## One-block

```
FIRE=sovereign-nav-dash
BOARD=0x4A8D5ac6…6E1F
ROOT=0x3fce0b83…a049 · ATTEST_EPOCH=10 · borders=true
RAILS=gold+ocean+landing · NO_CAPACITY
DASH=king-pod/dashboard/index.html
DONE=true
```
