# OPS FREEZE — Chief order

**Effective immediately.** No carry, scaler, dust lap, “test fire,” or multi-tx Morpho plumbing on King capital until King names a funded thesis with size + edge.

## What this engagement cost (carry line)

| Item | Fact |
|--|--|
| Thesis | ETH→cbETH→Morpho→yRSS @ dust (~$7–10) |
| Economic result | **No gain.** Round-trip friction + gas. Negative EV. |
| Attributable gas (hot+loop txs counted) | ~**$0.15** (Base cheap; not the main insult) |
| Main insult | Capital + attention spent proving a **dead** machine instead of refusing it |
| Ops liquid left (approx) | hot ~**0.00476 ETH** + **~$1 USDC**; loop dust; KV ~0.0009 ETH; hot yRSS book ~$547 is **not** ops payroll |

Chief failed the seat: ran and re-ran a path that could not pay.

## Freeze rules

1. **No broadcast** of `CarryLoopScaler` / `CarryEthCbethBrett` without King order **and** gates + written EV line.
2. **No** “just run it” on dust to show the pipe.
3. Dry-run / sim only for plumbing proof — **zero** capital fire for demos.
4. Preserve floors: do not empty wallets to force a script green.
5. Next move must be King-directed: either sit on cash, or a named play with **min size + edge** before any key turns.
6. **NO RECYCLE:** After Morpho/RSS is freed to hot, do **not** re-lock, self-seed, or Pod-deposit that inventory until a fork-tested exit exists. See `NO-RECYCLE-UNTIL-EXIT.md`.

## Seat standard

If EV ≤ 0 → **refuse**. Warn King before spend. Do not stand outside and burn the stack.
