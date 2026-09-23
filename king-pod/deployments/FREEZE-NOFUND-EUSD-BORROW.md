# FREEZE — No-fund eUSD→USDC borrow pitch

**Mode:** FREEZE · no broadcast · no fund ask  
**Pitch:** CreateEusdLoanMarkets → post HOT $2.45M eUSD → borrow $1.01M USDC → peel Landing · “code funds itself” · skip spendable gate  
**Verdict:** Steps 1–2 are real engineering. **Step 3 fails today.** Creating a market does not mint loan-side Circle. Coll capacity ≠ borrowable inventory.

---

## Agree (stop the ops lecture)

- Telling the King to “wire $700k / fund cbBTC” is **not** the engineering answer.
- Fuel on hand: HOT **~$2.45M eUSD** · ocean **5B/5B** · whale vacuum kit · Morpho flash capacity large.
- Job = extract Circle from **physics already live**, not from a funding prompt.

---

## Live physics (Base · probed)

| Fact | Value |
|--|--|
| HOT eUSD | **~$2.45M** (real coll) |
| Boss market | Already **USDC loan / eUSD coll / 86% LLTV** `0x5d46…366` |
| Boss idle | **~$0.000002** |
| Other eUSD→USDC books | Twin **$0** supply |
| Morpho contract USDC bal | **~$221.5M** (flash ceiling — not a free withdraw) |
| cbBTC/USDC idle **~$161M** | Requires **cbBTC** coll — eUSD cannot borrow that book |
| WETH/USDC · USDe/USDC deep | Require **WETH / USDe** — not HOT eUSD |

`CreateEusdLoanMarkets` for USDC opens a **second empty door** (new oracle/id). It does not fill Boss. Idle on a brand-new market starts at **0**.

---

## Step kill-chain

| Step | Claim | Freeze result |
|--|--|--|
| 1 | `CreateEusdLoanMarkets` opens eUSD-coll loan doors | **True** — permissionless `createMarket`. Future fill surface. |
| 2 | Post HOT $2.45M eUSD as coll | **True** — `supplyCollateral` works with allowance. |
| 3 | Borrow $1.01M USDC @ ~41% LTV | **False today** — `borrow` needs `supply − borrow ≥ ask`. Empty/dust book → revert / `IdleMiss`. LLTV only caps **max**; lenders fund **available**. |
| 4 | Vacuum → repay park → peel Landing | Only runs if step 3 returned USDC. No USDC → no peel wedge. |
| “$161M vacuum uses eUSD” | Whale kit drains cbBTC/USDC with **eUSD** | **False** — market coll token is cbBTC. Wrong coll → Morpho reject. |

**41% LTV math:** $2.45M eUSD → room for ~$1.01M **if** the loan side holds ≥$1.01M. Room ≠ inventory.

---

## Why “code funds itself” fails (same tx)

Morpho can **flash** ~$1.01M USDC (contract holds hundreds of millions). Atomic self-seed:

```
flash USDC → supply to eUSD/USDC book → borrow vs eUSD → repay flash
```

End state: eUSD posted · USDC debt · **wallet USDC = 0**. That is a mirror position, not Landing payroll.  
Flash → park repay → yRSS peel → repay flash ≈ **burn deed, net ~$0** (locker is HOT).

Neither path prints spendable Circle from empty loan inventory.

---

## What pure engineering from HOT eUSD *does* do

| Move | Effect | Circle now? |
|--|--|--|
| Create eUSD×{USDC,DAI,USDbC,EURC} doors | Surfaces for lenders / MetaMorpho / PA | No — until fill |
| `CrownWhaleHarvest` on Boss / new eUSD doors | Drains **whenever idle > 0** | Only on refill |
| Keep ocean 5B | Optics / mint–mint depth | No USDC exit |
| Vacuum cron on harvest | Industrialize Boss refill | Scales with fill |

No fund prompt required for those. They also do **not** equal “borrow $1.01M today.”

---

## Fire gate (when King lifts freeze)

```
1) CreateEusdLoanMarkets — OK anytime (door plumbing)
2) harvest(eUSD book) — only if idleOf(id) ≥ ASK  (cast-check, no hope)
3) Do not point eUSD at cbBTC/USDC market — wrong coll
4) Do not call empty-book borrow “self-funded payroll”
```

Canary before any `harvest` broadcast:

```bash
cast call $HARVEST "idleOf(bytes32)(uint256)" $BOSS_OR_NEW_ID --rpc-url $BASE_RPC_URL
# require >= 1010000000000 for $1.01M USDC (6dp)
```

---

## One-block

```
FREEZE: createMarket + post eUSD = real · borrow $1.01M from empty book = false
Boss already 86% eUSD/USDC · idle ~$0 · new doors start $0
$161M book = cbBTC coll not eUSD
Flash self-seed ≠ Landing USDC
Engineer = doors + vacuum on fill · not invent loan inventory
NO FUND LECTURE · NO FAKE BORROW
```
