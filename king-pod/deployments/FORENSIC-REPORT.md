# FORENSIC REPORT — live Base (facts only)

Checked just now. Prior agent notes contradicted each other. This corrects the record.

## RSS — where every token is

| Location | Amount |
|----------|--------|
| **Total supply** | **21,000,000,000** (21 billion) |
| V1 KingPair `0x56Eb…78F8c` | **20,981,500,000** |
| King hot `0x6708…a7d1` | **18,494,447.50** |
| KingSeedDesk `0xF43B…e8DF` | **5,552.50** |
| Morpho Blue | **0** |
| V1 / V2 markets / sale / closers | **0** (dust on V2 pair only) |
| **Unaccounted** | **~0** |

All supply is on-chain and located. Nothing “missing” from total supply.

**What “21M → 18.5M” means:** After Morpho unwind, King hot held ~**21 million liquid**. Hot is now ~**18.5 million liquid**. Desk holds **5,552** from elite-close fills (`totalRssSold` = 5,552 — **not** millions sold). The liquid drop of ~2.5M is **not** explained by desk fills alone — worker still owes a transfer trace for that liquid delta. It is **not** sitting in Morpho. It is **not** “sold off-market” as the main story. Most of the **21 billion** has always lived in the **V1 pair** as LP reserves.

**Correction:** Earlier talk that mixed “pod holds tokens” / “sold without King knowing” / “desk ate millions” was sloppy. Desk ate **~5.5k**. Pair holds **~21B**. Hot holds **~18.5M liquid**.

---

## Debt — live, not old docs

### Morpho RSS/USDC market (`0x40ac…b794`)
- King position: supply **0**, borrow **0**, collateral **0**
- Market supply: **7 wei** dust
- **No open Morpho debt.**

**Correction:** The “~$700k Morpho debt” in `king-pod-v2.json` was **stale** — written when self-lend book was open. That book was **unwound** (see `rss-freed-morpho` / free-RSS work). Live debt = **$0**.

### V2 KingMoneyMarket (`0x3F0f…20cF4`)
- King debt: **$0**
- King collateral LP: **0**
- sUSDC `totalAssets`: **1** wei (empty)
- **No open V2 debt.**

### V1 KingMoneyMarket (`0x50A6…2578`) — LIVE PROBLEM
- King `debtUsdc`: **$170,000**
- King `collateralLp`: **~3.55e19** (locked on market)
- V1 market USDC balance: **$0**
- V1 sUSDC `0x4af8…1021`: `totalAssets` = **0**, USDC balance = **0**, `totalSupply` = **170k** paper shares
- V1 pair holds the RSS + paper sUSDC
- Owner: King
- `releaseCollateral` **reverts** on live deploy (bytecode has no working exit)

**Fact:** V1 is a **$170k paper debt** against locked LP. **No hard USDC** left in sUSDC to withdraw. That is the stranded V1 book — not Morpho $700k.

---

## Hard USDC right now
- King hot: **$0**
- KingVault: **$4.87**
- yRSS vault: **$0**
- V1 / V2 / Morpho withdrawable USDC: **$0**

---

## What was wrong before
1. Saying Morpho still had ~$700k debt — **false today**
2. Mixing “tokens in pod” with liquid 21M wallet — **V1 pair holds billions of total supply; liquid wallet is separate**
3. Implying desk “sold” millions of RSS — **desk sold ~5.5k**
4. Scanning for “withdrawable USDC” on empty sUSDC — **already empty**

---

## Still open (worker continues)
- Transfer forensic for **liquid** 21M → 18.5M (~2.5M delta)
- Confirm no other wallets hold that liquid slice
- V1 exit research (no `releaseCollateral` on deploy) — separate from Morpho pipe

No txs without greenlight.
