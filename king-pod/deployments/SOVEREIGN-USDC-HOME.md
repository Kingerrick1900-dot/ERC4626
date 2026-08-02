# Sovereign USDC → Landing — corrected path (no new builds)

**Focus:** hard USDC on Base Landing to pay bills.  
**Live book:** ELE77 matched ~$17.5M · 25M ELE coll · flash debt 0.  
**Rule:** no new contracts — fire existing machines only.

## Other-scribe plan — corrected

| Step | Claim | Live truth |
|--|--|--|
| 1 | Use 100k eUSD on Scroll hot | **Yes** — hot holds ~**100,001 eUSD** (convert tranche). Cold keeps ~**545k**. |
| 2 | Reserve Protocol redeem → USDC+USDT | **No.** Token is **Kingdom Elepan USD** (`0x41Ba…1B0B`), gold-CDP credit — not Reserve. No `main()` / basket redeem. |
| 3–5 | Bridge → yELE → borrowIdle → Landing | Valid **after** hard USDC exists on Base. |

On-protocol eUSD exit without a USDC counterparty = **CDP repay → kXAU back**, not USDC.

## Generated solution (works with live tools)

Kingdom eUSD clears like Reserve only when **USDC is on the other side** (buyer / matcher / PSM seed). That is already built:

### Path S1 — Matcher completer (Scroll, preferred for eUSD)

1. Matcher supplies Scroll USDC into live completer `0x2cf08F81…66f6`.
2. `complete(amount)` → credit → **Scroll Landing** (existing dominion rail).
3. CCTP Scroll→Base to Base Landing when Base payroll needs it  
   (Base→Scroll messenger already scripted; reverse is same Circle burn/mint — no new contract).

### Path S2 — Hard USDC on Base → Landing (payroll direct)

When any hard USDC is on Base hot:

```text
USDC.transfer(Landing, amount)     # bills address — simplest
```

Optional Morpho shape (only if capital is **external** LP, not relocating King’s own cash):

```text
yELE.deposit → ELE77 idle → extractor.borrowIdle(ask) → Landing
```

Live extractor: `0x5d99EEf1…bf58`. Gate: idle ≥ ask.

### Path S3 — Seed clear then home (100k tranche)

1. Seed Scroll eUSD/USDC (or kingdom PSM) with **external** USDC ≥ convert size.  
2. Clear hot **100k eUSD → USDC** via existing `FireScrollEusdRail` / pool (min out set).  
3. Bridge USDC → Base Landing.

If King seeds with his **own** USDC to buy his own eUSD: net USDC ≈ 0 (retired eUSD only). Idle for bills requires **outside** USDC or a matcher.

## What we will not do

- Call Reserve redeem on Kingdom eUSD (false ABI / false hope).
- Dump 100k eUSD into the **$0.20** Uni pool.
- New builds.
- Treat matched ELE77 supply as spendable Landing cash.

## Scoreboard when done

| Metric | Target |
|--|--|
| Base Landing USDC | ≥ **$500,000** (ops) |
| ELE | still kingdom collateral — not sold |
| Cold eUSD | ≥ **545k** kept |

## Armed fires (King GO)

| Fire | Flag |
|--|--|
| Scroll 100k clear | `KING_GO=1 FIRE_EUSD_RAIL=1` + USDC depth ≥ ask |
| Base borrowIdle | `borrowIdle(ask)` when ELE77 idle ≥ ask |
| Disk fill | `FIRE_DISK_FILL=1` when hot holds USDC + queue live |

**Bottom line:** Idle is created by **real USDC in** (matcher / LP / raise), then existing rails bring it home. eUSD is the credit inventory; completer/PSM/pool is the clear — not Reserve.
