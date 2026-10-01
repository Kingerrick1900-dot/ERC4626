# Handoff — Locate & Secure Exit Funds

**Status:** RECONCILED · NOT COMPROMISED · NO FURTHER SWEEP REQUIRED  
**As-of:** Base block ~51983353+ · live `cast` reads

---

## 1. Trace — tx `0x25dbcab…3323`

| Field | Value |
|--|--|
| status | **success** |
| from | `0x6708e211…a7d1` (**HOT / King**) |
| to | `CrownExitNative` `0x97bd6846…bB68` |
| eUSD in | `2.660969 eUSD` (raw `2660969e12`) HOT → Exit |
| **USDC out** | raw `2660969` = **`$2.660969`** Exit → **HOT** |

USDC `Transfer` log data `0x289a69` = **2,660,969 base units**. USDC decimals = **6** → dollars = `2660969 / 1e6` = **$2.660969**.

### Unit error (root of the alarm)

| Misread | Correct |
|--|--|
| “$2.66M exited” / “2,660,969 USDC dollars” | **$2.660969** spendable USDC |
| Scoreboard `hotUsdc=2.660969` then `1.330485` | Same dollars; half supplied to Aave |

**No missing millions.** Prior labeling treated micro-USDC raw as whole dollars.

---

## 2. CrownExitNative custody & controls

| Check | Result |
|--|--|
| `owner()` | `0x6708e211…a7d1` = **HOT** |
| `hot()` | `0x6708e211…a7d1` = **HOT** |
| EIP-1967 proxy impl slot | **0** — not a proxy · **no upgrade key** |
| `exit` | `onlyHot` (owner \|\| hot) |
| `fundInventory` | permissionless **deposit only** (cannot drain) |
| `setArmor` / `setRate` / `transferOwnership` | `onlyOwner` |
| Unguarded withdraw / rescue / sweep | **none** |
| Current USDC inventory | **0** |
| Current cbBTC / WETH inventory | **0** |

**Verdict:** King-controlled. Not compromised. Halt **not** required.

Note: Exit holds `2.660969 eUSD` from the swap (no eUSD rescue on this contract). That is **not** spendable USDC.

---

## 3. Sweep

| Location | USDC | Action |
|--|--|--|
| ExitNative | **$0.00** | nothing to sweep |
| HOT wallet | **$1.330485** | already in King’s hand |
| CrownAaveSleeve aUSDC | **~$1.330488** | King-owned · left earning (see §4) |

Sweep executed where applicable: **N/A — Exit empty; HOT already credited.**

---

## 4. Aave sleeve

| Check | Result |
|--|--|
| Sleeve | `0x90ae3823d79175daB4095cF1Bf8C6dFB0c34cb47` |
| `owner()` / `hot()` | both **HOT** |
| Pool | Aave V3 Base `0xA238Dd80…d1c5` |
| aUSDC | `0x4e65fE4D…c0AB` |
| Supplied | 1,330,484 base units |
| Live aUSDC balance | **1,330,488** (accrual +4) → **earning** |
| Idle USDC on sleeve | **0** |

Custody clear · earning live · no sweep (per handoff §4).

King can recall anytime: `CrownAaveSleeve.withdrawToHot(0)` as HOT owner → USDC to HOT.

---

## 5. Real spendable dollars (King-controlled only)

| Wallet / vault | Asset | Raw | **USD** |
|--|--|--|--|
| **HOT** `0x6708…a7d1` | USDC | 1,330,485 | **$1.330485** |
| **CrownAaveSleeve** (HOT owner) | aUSDC | 1,330,488 | **$1.330488** (withdrawable → USDC) |
| ExitNative | USDC | 0 | **$0.00** |
| **Total King-controlled USDC-class** | | | **≈ $2.660973** |

No capacity. No estimates. No “minted eUSD” in this number.
