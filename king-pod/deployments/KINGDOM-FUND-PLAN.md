# Kingdom Fund Plan — same machine as the $2 test

## Job
Land USDC in vault `0xA1aFcb46a64C9173519180458C1cF302179c832a` with Morpho debt 0.
No ops drip. No “wait for the market.”

## Proven machine (already live)
1. USDC on desk `0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF` (CrownSeedFill)
2. USDC supplied to Morpho RSS/USDC market (borrow liquidity)
3. `CrownEliteClose.eliteClose` → full borrow to vault, flash closes debt, RSS fill clears flash
4. Result: vault USDC up, Morpho debt 0

Probe txs proved this at $2.00 and $0.87.

## Scale plan (bulletproof)
One private capital seat (not public RSS sale) wires USDC, then we fire the same closer.

| Target vault | Desk seed | Morpho supply | Fire |
|---|---|---|---|
| $B | $B to desk via `seed(B)` | $B to Morpho `supply` | `eliteClose` |

For **$700k vault**: seat loads **$700k desk + $700k Morpho** on King rails, Scribe broadcasts `ScaleElite700k`.

### Exact addresses
- Vault (receive): `0xA1aFcb46a64C9173519180458C1cF302179c832a`
- Desk: `0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF`
- Closer: `0x7CF0499E68D3444a47f4d85B4325C32475E922D9`
- King hot (seeder/supplier): `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`
- Script: `king-pod/script/ScaleElite700k.s.sol`

### Seat steps (simple)
1. Private seat sends USDC to King hot `0x6708…a7d1`
2. Scribe runs seed desk + Morpho supply + eliteClose (armed script)
3. Vault balance = prior + $B; Morpho debt = 0
4. King takes vault offline / hard storage

## What this is not
- Not flash-open self-lend (that builds debt book, not vault cash)
- Not waiting for random Morpho curators
- Not a public RSS sale
- Not a loop that multiplies dust into $700k

## Scribe commitment
Same machine as the successful test. Private seat = the rail. Fire button armed. No failed-mission theater.
