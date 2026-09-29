# FIRE — Curator 200M tranche chassis

**Mode:** FIRE chassis · Base  
**Doctrine:** Cap $200M. Cold eUSD stays. Gold locked. Payroll from yield — not King pocket. LLC after ops USDC exists.

---

## Live targets (deposit assets)

| Curator | Address | Role |
|--|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` | ~45% |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` | ~45% |
| Pendle PT sleeve | `CrownPendleSleeve` (parked USDC → PT when named) | ~10% ($20M at full cap) |

**Hard cap:** `CrownCuratorTranche.CAP = 200_000_000e6`

---

## Commands

```bash
# Fork prove ($1M deal — not claiming live 200M)
forge test --match-contract CuratorTrancheTest -vv

# Deploy chassis (no deposit unless TRANCHE_USDC set AND HOT holds USDC)
forge script script/FireCuratorTranche.s.sol:FireCuratorTranche \
  --rpc-url $BASE_RPC_URL --broadcast

# When fills land USDC on HOT:
TRANCHE_USDC=700000000000 forge script script/FireCuratorTranche.s.sol:FireCuratorTranche \
  --rpc-url $BASE_RPC_URL --broadcast   # $700k first slice under cap
```

---

## Multi-chain compounder

| Chain | Action |
|--|--|
| **Base** | Primary MetaMorpho deposits + harvest → Landing |
| **Polygon** | Mirror sleeve when USDC float exists (China desk) — same weights, separate instance |
| **Scroll** | Harvest sink / ops wallet `0xca76AE9e…F864` — yield consolidation |

Do **not** bridge the cold **$1.32B eUSD**. Only harvest **USDC yield** from the 200M tranche.

---

## Scoreboard

| Metric | Target |
|--|--|
| `totalDeployed` | ≤ $200M |
| Landing eUSD | ≥ ~$1.32B cold (unchanged by this fire) |
| Annual ops | ~$9M @ 4.5% once full tranche filled |
| LLC / payroll | Funded from harvest — **after** USDC is in curators |

```
FIRE=curator-200m-chassis
CAP=200e6 USDC
SPLIT=45/45/10 Gauntlet/Steak/PendleSleeve
COLD=1.32B eUSD Landing
BLOCK=no USDC on HOT → deploy(amt) skipped / NO_USDC
NEXT=external fill USDC → TRANCHE_USDC slices → harvest → payroll → then LLC
```
