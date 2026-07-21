# LIVE FIRE LAW — King Errick of Yahudah

**Rule (locked):**  
**No live deployments. No mainnet broadcasts. No new contract creates. No collateral moves. No desk changes.**  
**Unless the King explicitly says OK / GO / FIRE for that action.**

## King reads first (absolute)

**King must read the written plan before any live deployment.**

| Required before `--broadcast` | |
|-------------------------------|--|
| Plan doc in `deployments/` | King has read it |
| Scope clear | what moves, what wallet, what size |
| Explicit King words | **OK / GO / FIRE** for **that** plan |

Scribe may write and dry-run. Scribe may **not** live-fire because a script exists or a prior chat implied urgency.  
**No plan read by King → no live fire.**

Scribe may:

- Write code, scripts, docs, packets  
- Fork / simulate / `forge test` / dry-run (`FIRE_*=0`)  
- Read chain state  

Scribe may **not** without King OK:

- `--broadcast` on Base  
- `forge create` / deploy helpers / new markets  
- `supplyCollateral` / borrow / stock / arm / pause desk  
- Spend hot gas or move RSS/USDC  

Prior live steel already on-chain stays (desk, helper, posted coll) until King orders change.  
**No further live until King has read the plan and said OK.**

## Debt law (King order — never again)

- **Debt-free means zero borrow shares on-chain.** Verified after every debt fire. Not "mostly paid." Not "dust left on purpose."
- **Never leave intentional borrow dust** (no `DUST_DEBT`, no "rounding cushion" debt, no interest-accruing residue).
- **Never call a debt job done** while Morpho still shows borrow > 0.
- **Do the job ordered.** If King says clear debt, clear debt — full stop. No pivot to other objectives.
- If chunk-unwind cannot hit zero in one contract, **chain `CrownZeroMorpho.zeroBooks()` in the same fire plan** before reporting success.

## Debt access law (King order — absolute)

**No Morpho debt unless King can access spendable funds for the asset put up.**

| Forbidden | Why |
|-----------|-----|
| Flash self-seed / fortress (borrow to repay same flash) | Debt opens; wallet USDC = **0**; yRSS locked at 100% util |
| Borrow that only creates vault shares with no withdraw path | Debt without access |
| Any fire that leaves borrow > 0 while hot/Landing USDC unchanged | Violation |

| Allowed | Why |
|---------|-----|
| `borrow(..., receiver = Landing or Hot)` with real idle liquidity | King gets spendable USDC for the coll posted |
| Clear/zero debt fires | Restores access |

**`FireFlashAttack500` / fortress self-seed is FORBIDDEN** unless King explicitly says `ALLOW_FORTRESS_DEBT=1` **and** names spendable receiver. Default: **never.**

## Hot wallet law (King order — ops USDC)

**Hot `0x6708…a7d1` is the token/ops wallet.** It must **always** hold spendable USDC for seeds, BRETT scale, Ignition, and fire gas discipline.

| Rule | Detail |
|------|--------|
| **Never deposit all hot USDC into yRSS** | `FireWakeZeros` keeps `HOT_USDC_FLOOR` (default **$10**) on hot |
| **Never sweep hot USDC to Landing** | `FireHarvestSpoils` only sweeps **above** floor; fees → Landing OK |
| **Hot = Morpho signer** | `PRIVATE_KEY` must be hot `0x6708…a7d1` |
| **Loop = ops float** | `LOOP_PRIVATE_KEY` on `0x8d3cfbFc…8585` funds hot USDC/ETH — **not** Landing cold key |
| **Landing is cold treasury** | Buyer proceeds only; loop funds hot ops |
| **Flash fortress ≠ hot payroll** | Self-seed loops lock USDC in yRSS/debt; they do not replace hot float |

If hot USDC hits zero after a fire, **that fire violated this law.**

## Zero doctrine (King order)

Kingdom-controlled rails **must not sit at zero** when inventory exists to arm them:

| Must not be zero | Wake with |
|------------------|-----------|
| yRSS TVL | Deposit USDC **above hot floor only** (Landing peel → hot, keep ops float) + reallocate |
| Morpho RSS collateral (when armed posture) | `FireArmCreditLine` / `FireWakeZeros` |
| BRETT/USDC + RSS/USDC market supply | yRSS reallocate / lender deposit |
| Desk / bond **inventory** | `stock()` from hot RSS |

**Allowed at zero until commerce:** `raisedUsdc` on desk/bond (needs buyer). **Not allowed:** leaving vault TVL, posted coll, and market depth at zero while RSS/USDC inventory exists to seed them.

Script: `FireWakeZeros.s.sol` (`KING_OK=1` `FIRE_WAKE=1`).
