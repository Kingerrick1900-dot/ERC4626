# Engineer Morpho idle — CORRECT way

Scoreboard: Landing USDC. Block: RSS/$1200 `idle ≈ 0` (King matched book ~$200.8M / ~$200.8M).

## Morpho law (only three raise idle)

| # | Action | Effect |
|---|--------|--------|
| **1** | Unmatched `supply` | supply ↑, borrow same → idle ↑ |
| **2** | `repay` debt | borrow ↓, supply same → idle ↑ (**money is in the loans**) |
| **3** | Public Allocator `reallocateTo` | vault USDC moves into market → idle ↑ |

Not idle: Aero $0.67 LOOK, donate/sync optics, Peapods self-lend (leaves **100% util** on purpose).

## Chassis

`CrownEngineerIdle.sol`

| Call | What | Landing |
|------|------|---------|
| `proveIdleFromLoanBook(ask)` | Flash → **repay** King debt → peak idle ≥ ask → borrow-to-self → flash close | $0 (proof only) |
| `idleThenLoanToLanding(ask)` | Same idle engineer → **borrow to Landing** | **+$ask** (needs `ask` USDC buffer on chassis to close flash) |
| `idleFromUnmatchedSupply(ask)` | King USDC → supply → **lasting** idle | lasting idle for a later borrow |

## Fork proof

```bash
forge test --match-contract EngineerIdleFork -vvv
```

- Peak idle from loan book ≥ **$700k**
- Landing **+$700k** on `idleThenLoanToLanding` when buffer = ask
- Lasting idle ≥ **$700k** on unmatched supply

## Live read

- Buffer = ask is not “outside charity” — it’s the same USDC once. Without it, flash cannot close while Landing keeps the borrow.
- yRSS PA already has **maxIn $700k** on some RSS markets; vault TVL ~**$0.35** → PA tank empty. Correct wire, empty tank.
- Main book `0x41c08085…` has **PA realloc = 0** / no supplying vaults.

## Do not live-fire Landing path until buffer is real USDC on hot/chassis
