# Engineering plan (not a capital pitch)

## Correction
“Private Morpho fill” / “find a supplier” is **not** engineering. That was a counterparty ask. Scrapped from this doc.

## Physics (one time, then we stop repeating it)
Code cannot mint Circle USDC. Flash float must repay same tx. Empty Morpho market cannot borrow-and-hold. Self-supply + self-borrow ≈ relocates King’s own money; it does not create net hard USDC.

## What engineering already shipped
| Piece | Job | Creates new hard USDC? |
|-------|-----|------------------------|
| `CrownEliteFlashClose` (`railBps=0`) | Desk USDC → Morpho flash rail → RSS fill → vault | No — relocates desk→vault |
| `KingSeedDesk` | Holds fill inventory for the close | No |
| Loop/scale scripts | Automate seed+fire when capital exists | No |

Machine is parked. No fires without King greenlight.

## Engineering work that remains

### E1 — Hard-USDC census (accounting code)
Build/run a read-only inventory script over King-controlled addresses only:
- hot `0x6708…a7d1`, vault `0xA1aF…832a`, desk, flash closers, RSS sale, Morpho positions, V1 market/pair/sUSDC
- Output: **spendable USDC only** (ERC20 balance + withdrawable Morpho supply). Never count debt, LP book value, or RSS as cash.
- Deliverable: one number + per-address breakdown. Re-runnable.

### E2 — V1 lock autopsy (bytecode / owner / residual cash)
V1 market `0x50A61cA6b06563f1A44f7F2186A325b5301e2578`:
- Confirm live bytecode has **no** `releaseCollateral` (repo source ≠ deploy).
- Enumerate owner/operator powers that still exist on-chain.
- Measure residual hard USDC on market / sUSDC / pair (expect ~0 if already pulled).
- Deliverable: short autopsy note — **locked forever** vs **any remaining admin vector**. No hope budgeting.

### E3 — Fire path harden (when desk has real USDC)
- Single path: seed desk → `eliteFlashClose` → vault.
- Preflight: revert if desk USDC = 0 or Morpho flash cannot cover size.
- No auto-rail (`railBps` stays 0). No watcher. No dust loops as “growth.”
- Size fires to **desk balance**, not a fantasy mark.

### E4 — Do-not-build list (engineering discipline)
- Do not ship “activation / partner / public depositor” as a code milestone.
- Do not treat Morpho global float as this market’s liquidity.
- Do not treat V1 `$170k` debt as recoverable cash.
- Do not broadcast txs without greenlight.

## What this plan is not
It does not claim a software path from ~$4.87 + illiquid RSS + empty Morpho book to $700k. That outcome requires **new hard USDC entering the closed loop** (outside engineering) or **residual locked USDC still sitting on-chain** (E2). Engineering’s job here is census, autopsy, and a fail-closed machine — not fairy tales.

No txs without King greenlight.
