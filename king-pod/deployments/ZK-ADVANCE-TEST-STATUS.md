# ZK Advance Test — Status

**Ordered:** advance ≥ \$500k through CrownZkAdvance.  
**Rule:** fire only on **KING GO**.

| Check | State |
|-------|--------|
| Gate `isProven(hot)` | **true** |
| ZkAdvance | `0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B` |
| kUSD available | **~699,994** |
| Hot USDC | **~\$1.04** — cannot self-fund \$500k |
| Cold USDC | **\$0** |
| Broadcast | **HOLD — awaiting KING_GO + buyer USDC ≥ \$500k** |

Script: `FireZkAdvanceTest.s.sol`  
Requires: `KING_OK=1 KING_GO=1 FIRE_ZK_TEST=1 ADVANCE_USDC=500000e6`  
Optional: `BUYER_KEY` for counterparty signer.

On KING GO with funded buyer → broadcast → report tx hash immediately.
