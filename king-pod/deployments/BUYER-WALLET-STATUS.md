# Buyer Wallet Status — Unblock Report

**Designated King-controlled buyer:** Hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
(`PRIVATE_KEY` = this address. `BUYER_KEY` unset → defaults to hot.)

## Balances (now)

| Wallet | Address | USDC | Ready ≥ \$500k |
|--------|---------|------|----------------|
| **HOT (buyer)** | `0x6708…a7d1` | **\$1.04** | **NO** |
| COLD / Landing | `0x5Adc…2357` | \$0 | NO |
| LOOP | `0x8d3c…8585` | \$0 | NO |

## Gate / door

| | |
|--|--|
| ZK `isProven(hot)` | **true** |
| CrownZkAdvance stock | **~699,994 kUSD** |
| Calldata | Ready (`BUYER-ADVANCE-CALLDATA.md`) |

## Unblock (then KING GO)

1. **Fund hot** with ≥ \$500,000 USDC on Base (King-controlled), **or**  
2. Fund another King wallet and set env `BUYER_KEY=<that pk>`, **or**  
3. Trusted counterparty funds their wallet and broadcasts / provides `BUYER_KEY`.

Then: **KING GO** → scribe broadcasts `advance(500000e6)` → report hash · USDC on Landing · kUSD to buyer.

**Cannot fire now — buyer not loaded.**
