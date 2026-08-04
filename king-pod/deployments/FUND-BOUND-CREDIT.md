# Fund Bound Credit → Landing NOW

**Answer:** Yes. Funding credit through the Completer is the instant seed path.

## Live stack (already wired)

| Piece | Address | State |
|--|--|--|
| Gate proven (hot) | `0xab28…427F` | **true** @ **$700,000** |
| CrownZkCredit | `0x20B1…7D1A` | USDC pool **$0** |
| Completer | `0x3827…F7C6` | **operator=true** |
| AutoDraw | `0x364b…13ba` | **operator=true** |
| maxAsk | 70% × $700k | **$490,000** |
| Landing | `0x5Adc…2357` | receive |

## What `complete` does in one tx

1. Pull USDC from matcher/hot  
2. `credit.supply(amount)`  
3. `operatorBorrowTo(Landing, amount)`  
4. Landing USDC ↑ by `amount` · King debt ↑ by `amount`

That is the seed — **not** another yRSS loop.

## Block right now

| Wallet | Liquid USDC |
|--|--|
| Hot | **$0** |
| Credit | **$0** |
| Landing | ~$0.95 |
| Hot eUSD | ~**900k** — PSM/DEX redeem depth ≈ **$0** (cannot convert at size; keep-eUSD doctrine) |

So the machine is live; it needs **USDC on hot** (or a matcher calling `complete`) ≥ ask.

## Fire

```bash
# Status / dry
python3 king-pod/script/FireFundBoundCredit.py --dry

# When hot has USDC:
python3 king-pod/script/FireFundBoundCredit.py --fire --mode complete --amount 490000

# If credit already funded by matcher:
python3 king-pod/script/FireFundBoundCredit.py --fire --mode poke

# Hunt until USDC appears, then auto-complete
python3 king-pod/script/FireFundBoundCredit.py --watch --fire --amount 490000
```

## Matcher one-liner (external USDC)

Approve Completer `0x3827…F7C6` for `amount`, then:

`complete(amount)` with `amount ≤ 490000e6` → USDC lands on Landing same tx.
