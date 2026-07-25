# Liquid ops — real USDC + swap rail

## Live now

| Rail | Status |
|--|--|
| Hot USDC | **~$1–60** (pool seed took most of Landing sweep; ~$1 left liquid) |
| yELE-K $700k shares | **Unlocked** — claim residual ~$15.82 · see `POT-UNLOCK-LIVE.md` |
| ELE | **~14M** on hot |
| ELE/USDC UniV3 | **LIVE** `0x4615a3E4…7410` · see `ELE-USDC-POOL.md` |
| Landing | **FROZEN** · `LANDING-FROZEN.md` |

## Physics (do not rewrite)

- Morpho `supply(onBehalf=vault)` donation → inflate NAV → withdraw idle = flash body → **net $0**
- Debt-repay unlock → frees idle → withdraw → repay flash → **net $0**, shares cleared
- **$10 oracle market with no idle** → borrow reverts → **$0**; self-seed then borrow → **$0** circular
- Spendable ops USDC = **buyer USDC** (OTC / pool / foreign idle) — see `BUYER-PATH.md`

## Fire residual dust unlock (optional)

```bash
KING_GO=1 FIRE_POT_UNLOCK=1 \
forge script script/FirePotUnlock.s.sol:FirePotUnlock \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```
