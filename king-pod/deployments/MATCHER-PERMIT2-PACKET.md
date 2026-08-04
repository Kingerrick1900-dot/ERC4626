# Matcher packet — Permit2 Completer → Landing (Track A)

**Ask:** up to **$490,000 USDC** (70% × $700k proven Bound gate)  
**Settlement:** one Base tx → USDC on Landing  
**Elepan:** never touched  

## Live addresses (fill after deploy)

| Role | Address |
|--|--|
| Permit2 Completer | `0xA247c1d0Ad4E7690764E456E5d8d315bA2912468` **LIVE · operator=true** |
| Classic Completer (backup) | `0x3827dA0c33891ee058847BB896D6287C5814F7C6` |
| Credit | `0x20B1513a137b9CB166E2cC15c405e842278E7D1A` |
| Gate (proven hot) | `0xab2856626BBd8E6fba9dB93783029eB973E8427F` |
| Landing (receive) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| King / hot (borrower) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

## Path 1 — Permit2 (preferred)

1. Matcher signs Permit2 `PermitSingle`:
   - token = USDC  
   - amount ≥ ask (uint160)  
   - spender = **Permit2 Completer**  
   - expiration / nonce / sigDeadline set  
2. Anyone (King/keeper) calls:

```text
completeWithPermit2(matcher, amount, permitSingle, signature)
```

3. Effects: pull USDC → `credit.supply` → `operatorBorrowTo(Landing)` → Landing += amount · King credit debt += amount.

## Path 2 — ERC20 approve (backup)

```text
USDC.approve(completer, amount)
completer.complete(amount)
```

Works on Permit2 Completer **and** classic Completer `0x3827…`.

## Path 3 — Allowance already on Permit2

If matcher already approved Permit2 allowance to Completer spender:

```text
completeWithPermit2Allowance(matcher, amount)
```

## Terms for desk

- Asset: USDC on Base  
- Size: $100k / $250k / $490k tranches OK  
- Collateral story: Bound ZK gate proven $700k on hot (flash-bound reserves) + RSS Morpho fortress  
- Repay: King credit debt on `CrownZkCredit` (offchain schedule / ops yield)  
- Contact: efthompson008@gmail.com  

## King post-fill law

Landing USDC stays on Landing. No yRSS recycle. Elepan free.
