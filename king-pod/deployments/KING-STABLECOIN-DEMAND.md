# King's Stablecoin Plan — Demand-First Engineering

**Branch:** `cursor/king-stablecoin-demand-4f7f`  
**Doctrine:** Demand first. Config, not rewrite. Morpho **$200M signal untouched**.

Order: **Peapods scream → Merkl fixed depth → Liquity mint rail → Vault V2 0% exit → tax extract**

---

## 1 — Peapods PoD (first move)

Rate scream. Borrower creates demand. No waiting on depositors.

| Step | Action |
|--|--|
| Prep | `KING_GO=1 forge script FirePeapodsRss1200` (deploy pRSS/fUSDC/pair) |
| DEX | Seed **pRSS/fUSDC LP** so pfTKN/receipt is sellable at 100% util |
| Preflight | `./script/peapods_preflight.sh` (`PRSS` `FUSDC` `ASK_RSS`) |
| Scream | `KING_GO=1 FIRE_PEAPODS=1 ASK_RSS=834` (scale ASK_RSS up when ready) |

ELE reference already live. RSS stack on this branch.

---

## 2 — Merkl fixed (follow-up, not opener)

Market-level USDC supply on RSS/$1200. **Fixed reward rate only.**

Packet: `deployments/merkl-rss-1200-fixed.json`  
Target APR suggestion: **8% fixed** (override in Merkl UI). Variable = dilute early suppliers — **banned**.

---

## 3 — Liquity V2 pattern mint rail (config)

Chassis: `CrownRssTrove` — isolated CDP, mint eUSD vs free RSS. Same move as Liquity V2 (user-set rate, LTV, ceiling). Full `liquity/bold` deploy needs Liquity AG license; this ships the mint now on Kingdom eUSD.

| Param | Default |
|--|--|
| Oracle | RSS/$1200 `0xB584…` |
| LTV | **77%** (CR ~130%; override `LTV_WAD`) |
| Self-set rate | **5%** |
| Ceiling | **100,000,000 eUSD** |
| Mint default | **100M** → Landing |

```bash
python3 script/mint_size_100m.py
# ~129,871 RSS coll @ 77% +20% buffer; free ~14.7M — FITS

KING_OK=1 FIRE_TROVE=1 forge script script/FireRssTroveMint.s.sol:FireRssTroveMint \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

CR ladder via env: `LTV_WAD=909090909090909091` (110%) · `769230769230769231` (~130%) · `666666666666666667` (150%).

**Redemption floor (V2):** full BOLD fork adds global redeem-at-oracle. Kingdom v1: repay + unlock RSS on trove; peg via PSM + oracle trust. License bold when King wants Quill/Nerite-class redemptions.

---

## 4 — Vault V2 exit (0% penalty)

Live vault `0xB96B…A7b9` · adapter `0x3088…EE8c` · curator hot.

```bash
KING_OK=1 forge script script/SetVaultV2ZeroPenalty.s.sol:SetVaultV2ZeroPenalty \
  --rpc-url https://mainnet.base.org --broadcast -vvv
```

`forceDeallocate` flash exit already fork-proved. Penalty **0%** = gas-only — suppliers not trapped.

---

## 5 — Tax extract

When Merkl/PA creates **idle ≥ ask** on RSS/$1200: `BorrowIdleToLanding` (Phase 2 scripts). Signal book stays.

---

## Live inventory (post $200M signal)

| Item | Approx |
|--|--|
| Morpho RSS coll | **250k** (signal — leave) |
| Free RSS | **~14.7M** |
| 100M mint need | **~130k RSS** |
| Morpho flash | ~$238M |

---

## King GO checklist

1. [ ] Peapods prep + LP seed + preflight OK  
2. [ ] Peapods scream live (100% util)  
3. [ ] Merkl fixed campaign live on RSS/$1200  
4. [ ] Vault V2 penalty → 0%  
5. [ ] `mint_size_100m.py` FITS → `FIRE_TROVE=1` 100M  
6. [ ] Idle ≥ tax → BorrowIdleToLanding  

No soft wait. Each step is an engineered trigger.
