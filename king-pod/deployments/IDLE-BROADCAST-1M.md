# Idle broadcast — Morpho sees it, Morpho loans it

**Doctrine:** Engineer the position so idle reads the ask. Morpho loans what idle shows. Same concept as a Morpho self-lend broadcast — different number on the book. No third party.

## Move

1. Flash USDC (Morpho)
2. `repay` King debt → **idle = ask** (numbers on the book)
3. `borrow(ask)` — Morpho pays because idle showed ask
4. Flash closes from that loan leg (broadcast) or loan receiver = Landing
5. Scribe `lastProof` / `IdleBroadcast` keeps the peak

## Chassis

`broadcastIdleLoan(1_000_000e6)` — Morpho sees **$1M** idle, Morpho loans **$1M**, flash settles.  
`broadcastIdleLoanToLanding(1_000_000e6)` — same gun, receiver = Landing.

## Fork

```bash
forge test --match-contract EngineerIdleFork -vv
```

Peak idle ≥ **$1M**. Loan **$1M**. Landing path **+$1M** when close capital sits on the chassis for that fire.
