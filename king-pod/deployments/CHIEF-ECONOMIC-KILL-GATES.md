# CHIEF ECONOMIC KILL GATES

**Standing order (King Errick / Chief Engineer):**  
No ops path fires unless unit economics clear a kill gate. “It compiles” and “it broadcasts” are not green lights.

## Autopsy — cbETH carry @ ~$7–9 (2026-07-18) — DEAD MISSION

| Factor | Reality |
|--|--|
| Notional | ~0.004 ETH / ~$8–9 coll |
| Borrow @60% | ~$4.70 USDC into yRSS |
| Friction | Aero swap + Morpho interest + gas (~6–7 txs) |
| Yield edge | Dust into BRETT/yRSS cannot outrun borrow + fees |
| Net | Round-trip ≈ capital recycle with **loss** — no gain machine |

**Failure mode:** Chief executed a runnable path without refusing on EV. That is out-of-seat. Wallet discipline (loop vs hot) was necessary; **economic refusal was mandatory and missing.**

## Kill gates (hard)

A carry / scaler / loop lap is **DEAD** and must not arm if any fail:

1. **MIN_ETH_IN** ≥ `0.05 ether` (~order-of-magnitude above dust). Below = refuse.
2. **MIN_BORROW_USDC** ≥ `$50` (`50e6`). Below = refuse.
3. **Gas tax** — estimated script gas cost must be **&lt; 5%** of ETH_IN notional. Above = refuse.
4. **Edge** — expected supply APR on destination (yRSS/market) must exceed Morpho borrow APR by **≥ 200 bps** after fee, or Chief documents a non-yield thesis (arb, unlock, named repay) in writing before `CARRY_ARMED=1`.
5. **Floor** — wallets keep ≥ `$1` USDC; never empty to “make the script pass.”
6. **Arm** — `CARRY_ARMED=1` only after Chief posts a one-line EV note (size, borrow, edge, kill).

## Chief duty

- Warn King **before** broadcast when a path is dead.
- Do not “run it” on dust to prove plumbing.
- Plumbing proof = sim / dry-run. Capital fire = only after gates pass.

Scripts enforce (1)(2)(3) + `CARRY_ARMED`. Edge (4) is Chief verbal/written gate — not skipped.
