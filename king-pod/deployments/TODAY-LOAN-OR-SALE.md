# TODAY — Loan or Sale (new hard USDC only)

## Rule
The $4.87 vault balance was token-wallet recycle. It does **not** count as new capital.
No empty-market borrow. No paper LP. No dust spins. No txs without King greenlight.

## Goal
**New** hard USDC hits wallet today — size **$1 → $700k**. Loan or sale. Either works.

## Receive wallets (Base USDC)
| Use | Address |
|-----|---------|
| Hot (ops / loan receive) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Vault (stack) | `0xA1aFcb46a64C9173519180458C1cF302179c832a` |
| Desk (sale inventory → fire) | `0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF` |

---

## Path 1 — SALE (today)
**Contract:** `KingRssSale` `0xE9dA6F6ac49d42d82efD11BEE8946003bf22026e`  
**Price:** $0.05 / RSS (`50000` USDC raw per 1e18 RSS)

Buyer today:
1. USDC (Base) approve sale contract
2. `buyWithUsdc(usdcAmount)` or `buy(rssAmount)`
3. USDC lands King treasury/hot per sale config
4. King greenlights → Scribe seeds desk → `eliteFlashClose` (`railBps=0`) → vault

OTC sale today (no contract):
1. Buyer sends USDC to hot or vault
2. King sends RSS to buyer
3. If USDC on hot + greenlight → seed + fire to vault

---

## Path 2 — LOAN (today)
Lender today:
1. Sends USDC (Base) to **hot** or **vault** (King picks)
2. King escrows RSS as collateral (size agreed) to lender or escrow
3. Debt terms off-chain / simple note — Morpho book stays clean unless King later chooses Morpho

No Morpho borrow until **this** market has lender USDC. Empty book = $0 borrowable.

---

## What Scribe does on greenlight (same day)
1. Confirm inbound USDC tx on Base
2. If sale→hot: `approve` + `seed(desk)` + `eliteFlashClose` → vault
3. If loan→vault direct: done (debt is to lender, not Morpho)
4. Report: tx hash, wallet balance, Morpho debt = 0 (unless Morpho path later)

## Gate (honest)
**A counterparty must send hard USDC today.** Code cannot mint $1–$700k.  
Sale rail and loan receive addresses are live. Close the wire — wallet moves.

## Kill list
- Calling recycle dust “new funds”
- Borrow from empty Morpho market / $190M float confusion
- V1 paper sUSDC as cash
- Any broadcast without King greenlight
