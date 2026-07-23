# Sovereign Multi-Vault CDP — DEPLOY PLAN (NO LIVE FIRE)

**Status:** CODE READY · **NOT BROADCAST** until King `KING_GO`  
**Standard:** Access Clause mandatory · Landing treasury · isolated vaults · ZK-gated

---

## Access Clause (non-negotiable) — enforced in code

| Requirement | Implementation |
|--|--|
| Loan proceeds land immediately | `mint` / `mintTo` → **`treasury` (Landing)** in same tx |
| Vault never escrows eUSD | Assert `eusd.balanceOf(cdp)==0` after mint |
| Partial coll withdraw while debt open | `withdraw` if post-HF ≥ safety floor |
| Atomic full exit | `close` / `repayWithdrawCollateral` |
| King controls deployment of proceeds | eUSD sits on **Landing** — free to transfer/deploy |

---

## Gaps closed vs prior live deploys

| Gap | Fix in this plan |
|--|--|
| `feeRecipient` was hot | Redeploy with **Landing** |
| Elepan on separate eUSD | **One multi-minter eUSD** for all 3 vaults |
| Mint to msg.sender only | **`mintTo(Landing)`** + default `mint()` → treasury |
| Fee mint broke close if Landing held fees | `repay`/`close` **burn from treasury** |

Prior live vaults (`0xD010…`, `0x3b07…`, `0x6003…`, `0xb7Be…`) = **superseded** after Phase 1A.

---

## Canonical params (post Phase 1A)

| Vault | LR | Floor | Fee | Oracle |
|--|--|--|--|--|
| Elepan | 150% | 155% | 5%/yr | Soft $1 `0xe290…cf19` |
| WETH | 130% | 135% | 5%/yr | Uni TWAP 1800s WETH/USDC |
| cbBTC | 130% | 135% | 5%/yr | Uni TWAP 1800s cbBTC/USDC |

| Role | Address |
|--|--|
| Owner / ZK subject | hot `0x6708…a7d1` |
| Treasury + feeRecipient | Landing `0x5Adc…2357` |
| ZK gate | `0xca2a…3f30` |

---

## Phase order (deploy)

### Phase 1A — Redeploy stack (no mint)
```bash
cd king-pod
KING_GO=1 FIRE_SOVEREIGN_CDP=1 forge script \
  script/FireSovereignCdpStack.s.sol:FireSovereignCdpStack \
  --rpc-url $RPC --broadcast --slow
```
**Outputs:** eUSD + Elepan/WETH/cbBTC CDPs (all minters set, treasury=Landing).

### Phase 1B — Mint $13M eUSD → Landing
```bash
KING_GO=1 FIRE_MINT_13M=1 ELEPAN_CDP=<from 1A> forge script \
  script/FireSovereignMint13M.s.sol:FireSovereignMint13M \
  --rpc-url $RPC --broadcast --slow
```
| Input | Value |
|--|--|
| Coll | **20.2M Elepan** (~$20.2M soft, HF buffer over 155%) |
| Mint | **13_000_000 eUSD** → Landing |
| Year-1 fee (if debt stays open) | **~$650k** to Landing |

### Phase 2 — Optional (after 1B, separate GO)
Deploy Landing eUSD into Morpho lending — **re-quote APY at fire**; do not hardcode.

### Phase 3 — Optional PSM
Only if eUSD↔USDC external route needed.

---

## Pre-flight checklist (before any GO)

- [ ] Hot ZK `isProven=true` (7d TTL)
- [ ] Hot ETH gas ≥ **0.01**
- [ ] Hot Elepan ≥ **20.2M**
- [ ] `forge test` CDP suites **26/26 PASS**
- [ ] King names **GO flags** explicitly (`FIRE_SOVEREIGN_CDP` then `FIRE_MINT_13M`)

---

## Revenue (sovereign — no outsiders required)

| Source | Mechanic |
|--|--|
| **5% stability fee** | Accrues on open eUSD debt → fee eUSD minted to Landing |
| Morpho vault 10% | Parallel optional |
| Morpho eUSD supply | Phase 2 optional |

**Maker path:** mint vs own coll → debt open → fee to treasury. Outsiders never required.

---

## Contracts / scripts

| File | Role |
|--|--|
| `CrownAssetCdpVault.sol` | Shared engine + Access Clause |
| `CrownElepanCdpVault.sol` | Elepan isolated |
| `CrownWethCdpVault.sol` / `CrownCbbtcCdpVault.sol` | Isolated |
| `FireSovereignCdpStack.s.sol` | Phase 1A |
| `FireSovereignMint13M.s.sol` | Phase 1B |

**Nothing live until King GO.**
