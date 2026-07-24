# $500k Extract — Armed

Two engineered pulls. No deferred essays.

## Path 1 — Morpho borrow $500k → Landing
Headroom live **~$1.40M**. On idle ≥ $500k:

```bash
KING_GO=1 FIRE_BORROW=1 BORROW_USDC=500000000000 IDLE_FLOOR=500000000000 \
  forge script script/FireElepanBorrowUsdc.s.sol:FireElepanBorrowUsdc \
  --rpc-url $BASE_RPC --broadcast --slow
```

## Path 2 — Sell / transfer yELE shares ($500k face) → USDC to Landing
Landing holds **100%** of yELE (~$14.0M). Shares for $500k face ≈ sized in script.

```bash
KING_GO=1 FIRE_YELE_SHARES=1 MODE=transfer TO=<buyer> USDC_FACE=500000000000 \
  forge script script/FireYeleShareExtract.s.sol:FireYeleShareExtract \
  --rpc-url $BASE_RPC --broadcast --slow
# MODE=escrow → park shares in CrownYeleShareEscrow until buyer pays USDC to Landing
```

## Path 3 — ZK auto-draw
Credit supply ≥ ask → `CrownZkAutoDraw.poke()` at `0xB6481E2ca95c14BC47B29b60fec6eF7e4A398a23`

## Path 4 — Institutional
`INSTITUTIONAL-CASH-LANE.md` — Ledn BTC / Galaxy ≥$1M desk packet
