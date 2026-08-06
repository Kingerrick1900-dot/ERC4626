# Freeze — prove idle (last stage before Landing cash)

King: no anger path. Tools we own. No user money. No steal.

## Hard split (do not blur)

| Lever | What it does on Morpho | Creates idle USDC? |
|-------|------------------------|--------------------|
| **Idle** = `supply − borrow` | Real loan-token accounting | **This is the block** |
| **Oracle** `price()` | Collateral value / max LTV | **No** — never mints idle |
| Aero $0.67 LOOK | DEX reserve optics | **No** |

Oracle work (even legal fixed oracles) **cannot** replace idle. Morpho `borrow` pays out only when `liquidityAssets ≥ ask`.

## What protocols actually did (2025–2026) — fair game vs out

| Pattern | Who / when | Legal / intended? | Helps our idle? |
|---------|------------|-------------------|-----------------|
| **Morpho FixedOracle / creator-chosen `IOracle`** | Morpho docs; King RSS/$1200 oracle already fixed **$1200** (`0xB584…` → `1.2e27`) | Yes — market design | Prices coll only |
| **Pendle Linear Discount oracle** on Morpho/Aave | Gauntlet / Steakhouse 2025–26 | Yes — anti-manip pricing | Prices PT coll only |
| **Flash → repay → ephemeral idle → rematch** | Sovereign loan-book (our chassis) | Yes — own debt | **Yes — proves idle** |
| **Unmatched supply / PA `reallocateTo`** | Morpho Public Allocator | Yes | Yes if vault has USDC |
| **Peapods self-lend PoD** | Peapods LVF | Yes | Leaves **100% util** (anti-idle) |
| **Aero LP reserve oracle pump → overborrow** | Clearstar cUSDO Morpho **May 2025** — ~$48k lender loss, curator repaid | **Attack / bad debt** | Out of bounds — steals from suppliers |

TWAP/reserve games that drain **other people’s** deposits are not “ZK fair game.” Creator fixed oracles and own-book flash/repay are.

## This stage = PROVE idle (not keep Landing cash yet)

Chassis: `CrownEngineerIdle`

1. Morpho flash `ask`
2. `repay` King’s own debt → **idle ≥ ask** (money in the loans)
3. **Scribe** `lastProof` + `IdleProven` event (durable after rematch)
4. Borrow back to chassis → flash closes  
5. Lasting market idle returns ~0 — proof remains on contract

Fork: peak idle **$700,000.000001**. No $700k buffer required for prove mode.

Landing keep (`idleThenLoanToLanding`) still needs buffer = ask — separate stage after proof is accepted.

## Tools we already have

- Matched book ~$200.8M (King both sides) → repay engineers idle
- Free RSS, fixed $1200 oracle (immutable on this market)
- yRSS PA `maxIn` $700k on some RSS markets — tank ~$0.35 (wire exists, empty)
- Landing ~$700k **eUSD** (scoreboard is USDC — later rail)

## Live prove (when King says GO)

Deploy `CrownEngineerIdle` → `morpho.setAuthorization(eng, true)` → `proveIdleFromLoanBook(700_000e6)` → read `lastProof.ok` / `peakIdle`.

Gas only. No buffer. Landing USDC unchanged. Scribe holds the proof.
