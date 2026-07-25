# Liquid ops — live rails

## Live now

| Rail | Status |
|--|--|
| Hot USDC | **$1** liquid |
| ELE | **0** free — **~14M** posted on **$10 / 91.5%** self-seed book |
| $10 self-seed | **LIVE** · see `SELF-SEED-TEN-LIVE.md` · supply=borrow=$700k |
| ELE/USDC UniV3 | **LIVE** `0x4615a3E4…7410` · see `ELE-USDC-POOL.md` |
| yELE-K | unlocked residual ~$15.82 · `POT-UNLOCK-LIVE.md` |
| Landing | **FROZEN** · `LANDING-FROZEN.md` |

## Physics

- Self-seed flash → supply → borrow → repay flash = **matched book**, wallet USDC **Δ ≈ 0**
- $10 oracle sizes headroom; does not create idle beyond what was seeded
- Pot unlock / NAV donate = same conservation law

## Fire

```bash
# $10 oracle + createMarket + $700k self-seed (already live)
KING_GO=1 FIRE_SELF_SEED_TEN=1 \
forge script script/FireSelfSeedTen.s.sol:FireSelfSeedTen \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```
