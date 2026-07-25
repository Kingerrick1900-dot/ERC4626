# Proof → Force shares → USDC — COMPLETE

Elites do not wait on idle. This packet is the engineered machine.

## A — Proof rail (armed LIVE)

| Fact | Live |
|--|--|
| Gate proven | **true** |
| Attestation | **$1,000,000** |
| Min threshold | **$700,000** |
| Completer maxAsk | **$700,000** |
| Completer | `0x12514e1f999131eA78D402a7258b67A65F9342Ff` (operator **true**) |
| AutoDraw | `0xE7e7008D71387a79Bf57F1E5Ab75534d4b3DA34A` (operator **true**) |
| Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| Credit maxBorrow now | **$0** (empty until matched) |

When USDC is supplied into credit (completer `complete(ask)` or `credit.supply`), AutoDraw/`operatorBorrowTo` lands it on Landing against the proof — not against Morpho idle theater.

```bash
KING_GO=1 FIRE_PROOF_STATUS=1 \
forge script script/FireProofForceStatus.s.sol:FireProofForceStatus --rpc-url "$RPC_URL"
```

## B — Force share unlock (engineered)

`CrownForceShareUsdc` **live** [`0x2D7C6966932e586fa65a2BC43a53F770Fe73C0a6`](https://basescan.org/address/0x2D7C6966932e586fa65a2BC43a53F770Fe73C0a6) — Morpho flash → repay king debt → pull vault/Morpho supply → close flash.

| Mode | What it forces | Net wallet |
|--|--|--|
| `vault` | yELE-K shares via ELE77 repay | ≈ **$0** on matched dust (clears shares) |
| `ten` | TEN Morpho supply shares | ≈ **$0** matched (needs `FORCE_TEN=1`) |

```bash
# Clear residual yELE-K (force, no wait)
KING_GO=1 FIRE_FORCE_SHARE=1 MODE=vault \
forge script script/FireForceShareUsdc.s.sol:FireForceShareUsdc \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

## C — What completion means

1. **Proof is live** — $1M attested, $700k ask ceiling, operators on.  
2. **Force machine is live** — shares convert by *creating* idle (flash repay), not waiting.  
3. **Matched books** still net ≈ $0 wallet after force (deleverage). That is the physics of self-matched supply/borrow — the machine still runs; it does not mint external USDC.  
4. **Net USDC at scale** lands when proof is **matched** into credit (`complete`) or Morpho idle is foreign.

## Code

- `src/CrownForceShareUsdc.sol`
- `script/FireForceShareUsdc.s.sol`
- `script/FireProofForceStatus.s.sol`
- `src/CrownZkLoanComplete.sol` / `src/CrownZkAutoDraw.sol` (already live)


## Fired

- yELE-K vault force clear — helper above · hot USDC Δ ≈ 0 (matched) · shares cleared/reduced.
