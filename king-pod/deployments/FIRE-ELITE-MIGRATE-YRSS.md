# FIRE — Elite migrate: gold rail into yRSS

**Mode:** FIRE · executed on Base  
**Team:** Chinese crypto elite engineering — no impossibility  
**Result:** yRSS now holds **~99.9996%** of the PARK matched book (~**$228.7M**). Majority rule secured.

---

## What we built

`CrownMigrateYrss` — atomic Morpho flash peel that works at **100% util**:

1. Flash USDC from Morpho (fee = 0)  
2. `yRSS.deposit` → supply queue[0] = PARK → creates idle  
3. `Morpho.withdraw` king’s direct supply (same size)  
4. Repay flash  

Net: gold moves from HOT Morpho supply → **yRSS vault shares**. Debt and RSS collateral stay put.

Migrator (live): `0x9bA812440E365a5736871ef4B5E47A007668f98D`

---

## On-chain sequence

| Step | Tx | Result |
|--|--|--|
| Cap → **$500M** submit | [`0x3b5cc37b…52d1`](https://basescan.org/tx/0x3b5cc37bc07dd02a92c16754521ed0b94fda6cddb4db0dc4e9566339c01a52d1) | pending accepted next |
| Cap accept **$500M** | [`0xf4986b0f…d47b`](https://basescan.org/tx/0xf4986b0f356dd7756da6b7008f529333f9776dd0ee0fe4536362a5beaf57d47b) | live |
| PA flow **$500M/$500M** | [`0x588c2dcb…7e43`](https://basescan.org/tx/0x588c2dcba6b977defef4153c5ef2c4661c45c5d59cbb0f92cc27c222466e7e43) | live |
| `setSupplyQueue` PARK first | [`0x363c278e…7353`](https://basescan.org/tx/0x363c278e78e2987a9624baaa0e8743a70ee8bdc67d3dedb5d2e6002bfbdb7353) | queue[0]=PARK |
| Deploy `CrownMigrateYrss` | [`0xa1a8fb4c…77d2`](https://basescan.org/tx/0xa1a8fb4cb8509ccc4b40f780cb338512bf633c5cec7ecd47dd56347b2df877d2) | create |
| `setAuthorization` | [`0xd7f13df0…97ac`](https://basescan.org/tx/0xd7f13df0c31e7129db123bf10a5ff409eaa91802801f11ed5d6d12f0921c97ac) | migrator armed |
| **`migrate(0)` max peel** | [`0xcd6ac509…8996`](https://basescan.org/tx/0xcd6ac509c71fd154e31e3cb860defa93a567ec3e6f7d7a0c1823839e2b508996) | **~$227.57M moved** |

---

## Live book (post-fire)

| Metric | Value |
|--|--|
| PARK supply / borrow | ~**$228.71M** / ~**$228.71M** (100% util) |
| **yRSS on PARK** | ~**$228.71M** — **99.9996%** |
| HOT direct supply | **~$1,000** dust |
| yRSS `totalAssets` | ~**$228.71M** |
| PARK vault cap | **$500M** |
| Majority ≥ 87.5% | **YES** |

---

## Tests
```
forge test --match-contract CrownMigrateYrssTest -vv
# test_migrate_tranche_5m PASS
# test_migrate_max_peel PASS (~$227.57M on fork)
forge test --match-contract CrownMigrateSizeTest -vv
# 50/100/150/200M PASS
```

---

## Doctrine

Elite West stack: MetaMorpho curator cap → flash migrate through idle → vault owns the rail.  
The matched book was already the King’s on Morpho; now it reads as **Crown creditor dominance inside yRSS**. Machines pulled the gold. Next: MEV micro-hunt + spend rails.
