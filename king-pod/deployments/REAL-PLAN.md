# Real plan — vault USDC with debt 0

## Facts
- Flash/elite close **moves** desk USDC → vault. It does not mint.
- Auto-rail spins the same pile. Kill that as a growth strategy.
- King free RSS ≈ **18.5M** ≈ **$925k** oracle / **~$712k** max Morpho borrow at 77% LLTV.
- Morpho market liquidity now ≈ **$0**. No external lenders to borrow from.
- Sale desk already live: `0xE9dA6F6ac49d42d82efD11BEE8946003bf22026e` @ **$0.05/RSS**.

## Only path that stacks vault with debt 0
**USDC buyer for RSS → desk inventory → eliteFlashClose → vault.**

| Step | Action | Result |
|------|--------|--------|
| 1 | Buyer pays USDC for RSS (sale contract or desk `seed`) | Rail has real USDC |
| 2 | Fire `0x39D8…1a41` eliteFlashClose (set `railBps=0` so 100% → vault) | Vault +B, debt 0 |
| 3 | Repeat while buyers refill desk | Vault climbs |

Flash is the accelerator. **Buyer USDC is the fuel.** No buyer → no vault growth.

## Two buyer rails (pick one, run both if you can)
1. **KingRssSale** `0xE9dA…026e` — public/private buyers call `buy` / `buyWithUsdc`. USDC → King hot → seed desk → fire.
2. **Private desk seed** — ally/seeder `seed(USDC)` on `0xF43B…e8DF` → fire same tx path.

## What not to run
- Dust loops / auto-rail 100% recycle (no growth)
- Flash-open self-lend (debt book, vault unchanged)
- Waiting for Morpho curators with empty market

## Scribe job from here
1. `setRailBps(0)` on closer — every fire pays vault, not recycle
2. Wire sale → hot → desk → fire as one button when USDC arrives
3. No agent burn on empty-rail watching unless King wants the watcher

## Mark math
Vault target $700k ≈ need **~$700k USDC bought against RSS** through desk/sale, then one or many elite fires. RSS inventory is enough on paper; **cash bid** is the gate.
