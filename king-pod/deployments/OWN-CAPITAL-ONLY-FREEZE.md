# OWN CAPITAL ONLY — HARD FREEZE

**Mode:** FREEZE · **Effective:** 2026-08-04 · **Authority:** King Errick, day-one doctrine

## Doctrine (non-negotiable)

**We do not use other people’s capital.**

The only USDC that may leave a Morpho market to Landing is a **loan against the King’s own assets**, funded by **liquidity the King (or an explicitly consenting counterparty) seeded**.

| Allowed | Forbidden |
|--|--|
| King seeds USDC into **his** market → posts **his** RSS → borrows to Landing | Flash → `supply(onBehalf=vault)` → NAV inflate → redeem surplus |
| Explicit, consenting LP seeds the same market, disclosed oracle | Pulling USDC that sits for third-party vault depositors |
| Own-asset Morpho borrow (collateral = King RSS / King eUSD rails) | Resolv-class donation / share-NAV extraction against foreign books |
| | Enabling $1200 oracle on vaults that hold **other people’s** deposits |
| | Public Allocator / auto-routers that can shove third-party vault liquidity into the $1200 market |
| | “Bootstrap from Morpho idle / foreign PA / other curators’ queues” |

## What is frozen (no fire)

1. **NAV / donation path** — flash USDC → `supply(onBehalf=yRSS)` → redeem shares for surplus → repay flash. **Dead.**
2. **yRSS enable of $1200 market** while any third-party shares or foreign withdraw-queue exposure exists — **do not enable.**
3. **Any draw** whose USDC provenance is not 100% King-seeded (or named consenting counterparty).
4. **Broadcast** of scripts that implement the above until King lifts this freeze in writing.

## What the $1200 market is (and is not)

| | |
|--|--|
| Market | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| Oracle | `0xB5840644142B341a6145335e2ebc82EEBC7aE1B9` — immutable **$1200** / RSS |
| Status | **Created.** Tooling only. Not a license to touch foreign capital. |
| Clean use | King supplies **his** USDC · posts **his** RSS · borrows **his** loan to Landing |

Headroom under $1200 × 77% LLTV is **capacity**, not cash. Cash to Landing = USDC actually seeded by King/consenting LP, then borrowed against King collateral.

## Capital-source test (must pass before any draw)

1. Who supplied the USDC sitting in the market? → **King wallet / named consenting counterparty only.**
2. Whose collateral backs the borrow? → **King’s RSS (or other King asset), not vault share games.**
3. Can any third-party MetaMorpho vault, PA flow cap, or withdraw queue see this oracle? → **Must be No.**
4. Is any step a donation / onBehalf NAV inflate / redeem surplus? → **Must be No.**

If any answer fails → **do not fire.**

## Agent standing order

- Info / docs / dry-run sims only until King lifts freeze.
- No NAV, no `onBehalf` donation, no foreign-vault enable, no PA maxIn into $1200 for foreign books.
- Next funded thesis must name: **own seed size + own collateral + Landing receiver** — nothing else.

See also: `KING-ERRICK-HANDOFF-FREEZE.md` · `OPS-FREEZE.md` · `RSS-1200-MARKET.md`
