# EARLY-25-APR — Mansa Early Buyer Vault (Spec)

**Status:** SPEC ONLY — no deploy until King GO  
**Stacks on:** Prime Brokerage (`CrownPrime7683Fill`, `CrownLitePsm`, `USDCBorrowRouter`, `SelfRepayingTreasury`)  
**Doctrine:** Real fee yield to early USDC seeders. Cap + decay. Not a ponzi.

---

## King plan (≤120 words)

King carves **100M eUSD** from the 4B float as a *subsidized early pool* — customer acquisition mint, not team dump. First buyers fill `CrownPrime7683Fill` with USDC (e.g. $1M → ~$1.04M eUSD at 4% discount), then stake. **25% APR is paid from real revenue, not new deposits:** LitePSM swap fees (~0.05% on buffer volume) plus Morpho lending spread on USDC drawn via `USDCBorrowRouter`, swept by `SelfRepayingTreasury`. For 90 days, treasury routes **70% of fees** to early stakers — **first $10M USDC only**. Math: $10M × 25% = $2.5M needed; ~$1.8M PSM fees + ~$2.6M lend spread ≈ $4.4M cover. Cap + decay (25% → 12% → 8%). Principal freely unstakes → LitePSM 1:1. Early buyers seed the idle that arms the router forever.

---

## Mechanics

| Step | Action | Contract |
|------|--------|----------|
| 1 | Carve 100M eUSD fill buffer | King → `CrownPrime7683Fill.seedFillBuffer` |
| 2 | Buyers send USDC, get discounted eUSD | `CrownPrime7683Fill.fill` |
| 3 | Stake eUSD in Early Vault | `MansaEarlyVault` (to build) |
| 4 | Fees → treasury → 70% to vault (90d) | `SelfRepayingTreasury` route |
| 5 | Cap $10M USDC notional; then decay APR | Vault params |
| 6 | Unstake → redeem eUSD→USDC via LitePSM | `CrownLitePsm.buyGem` |

## Hard gates (anti-ponzi)

1. **Yield source = protocol fees + lending spread only.** No minting eUSD to pay APR.
2. **Deposit cap = $10M USDC** cumulative. No “next buyer pays prior.”
3. **Time box = 90 days** at Mansa rate, then decay schedule.
4. **Principal liquidity** via LitePSM reserves — not exit-from-new-deposits.
5. **No team approval path** for APR — params fixed at deploy / King-set once.
6. **Idle created is protocol-owned USDC** in `CrownPrimeCredit` — arms router permanently.

## Target math (illustrative)

| Stream | Assumption | Annual |
|--------|------------|--------|
| LitePSM fee | $10M/day × 0.05% | ~$1.8M |
| Lending spread | Drawn idle @ ~10% net to treasury | ~$2.6M |
| **Total real cover** | | **~$4.4M** |
| Early need | $10M × 25% | **$2.5M** |

Surplus after early period stays in treasury for debt repay + buffer growth.

## Build order (when King GO)

1. `MansaEarlyVault.sol` — stake eUSD, claim USDC yield, cap, decay.
2. Wire `SelfRepayingTreasury` fee split: 70% Early / 30% credit repay (90d), then flip.
3. Fork-test: fill → stake → fee → claim; prove APR not funded by later deposits.
4. Deploy disarmed; King seeds 100M eUSD buffer; open fill.

## Non-goals

- No recursive “deposit eUSD to earn eUSD mint.”
- No uncapped points farm.
- No touching team multisig for each payout — autonomous sweep.

No weak plans. Seed idle with Mansa terms; keep the dollars.
