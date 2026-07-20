# Step A — fill the shelf (found)

**What Step A is:** Put USDC where Public Allocator can **pull from** before `FireKingLoanRestore` borrows to King wallet.

---

## Status now (live)

| Piece | Status |
|-------|--------|
| `ArmYrssMultiMarket` — caps + PA flow caps cbBTC/WETH/RSS (~$700k) | **DONE on-chain** |
| `ArmYrssPipe` — PA admin hot, fee 0 | **DONE** |
| yRSS TVL / shelf stock | **~$0** (dust only) |
| cbBTC/WETH yRSS supply (PA pull source) | **$0** |
| Gauntlet/Steakhouse maxIn on RSS market | **$0** (foreign door closed) |

**We are waiting for shelf stock.** Wiring is armed; shelf is empty.

---

## Step A — three paths (pick one)

### A1 — Internal prime (King curator, no wallet USDC)

**When:** yRSS has TVL (depositors magnet in).

**Script:** `script/StepAPrimePullShelf.s.sol`

```bash
KING_GO=1 STEP_A=1 PRIVATE_KEY=<hot> \
  forge script script/StepAPrimePullShelf.s.sol --rpc-url $RPC --broadcast -vvvv
```

**Does:** Queue cbBTC first → reallocate all yRSS USDC into **cbBTC/USDC** (PA maxOut shelf).

**Then:** `FireKingLoanRestore` PA-pulls cbBTC → RSS → borrow to Landing.

**When `yRSS.totalAssets()` is dust:** script will still set the `supplyQueue` (cbBTC first) and **skip reallocate** until deposits arrive.

---

### A2 — Foreign curator door (WHALE PLAN primary)

**When:** King wants scale **without** yRSS TVL.

**Action:** Curator packet to **Gauntlet USDC Prime** + **Steakhouse Prime** — set PA `flowCaps` **maxIn ≥ $500k–$5M** on Kingdom RSS market `0x40ac09f3…`.

| Vault | Address |
|-------|---------|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` |

**Then:** `FireKingLoanRestore` with `PA_VAULT=<Gauntlet or Steakhouse>` (needs script update) — pull from **their** cbBTC book into RSS.

**Doc:** `deployments/WHALE-SCALE-PLAN.md` Play A, step A2.

---

### A3 — Magnet deposit (passive)

**When:** Rate magnet pulls outside USDC into yRSS.

**Script:** `DepositYrss.s.sol` (any depositor, not necessarily King).

```bash
AMOUNT_USDC=500000000000 PRIVATE_KEY=<depositor> \
  forge script script/DepositYrss.s.sol --rpc-url $RPC --broadcast
```

**Then:** run A1 internal prime → restore borrow.

---

## Already in repo (Step A building blocks)

| File | Role |
|------|------|
| `ArmYrssMultiMarket.s.sol` | Arm cbBTC/WETH/RSS caps + PA caps |
| `ArmYrssPipe.s.sol` | Oracle $1, RSS cap, PA on yRSS |
| `ActivateBrettMarket.s.sol` | Reallocate pattern (reference) |
| `DepositYrss.s.sol` | Stock yRSS TVL |
| `StepAPrimePullShelf.s.sol` | **NEW** — move TVL to cbBTC shelf |
| `FireKingLoanRestore.s.sol` | Step B+C — PA pull + borrow to wallet |

---

## Sequence when shelf fills

```
Step A  →  shelf stocked (cbBTC under yRSS OR foreign maxIn live)
Step B  →  FireKingLoanRestore (PA pull → RSS idle)
Step C  →  same tx: borrow USDC → King wallet
```

---

## King answer: what are we waiting for?

**One of:**
1. **Depositors** into yRSS (then A1 script), or  
2. **Gauntlet/Steakhouse** open maxIn on RSS market (A2 packet), or  
3. **Any USDC** into yRSS via magnet (A3).

Not waiting on new code. Waiting on **liquidity on the shelf**.
