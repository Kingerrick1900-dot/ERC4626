# ZK Self-Advance $500k — Hot Is The Buyer

No external counterparty. **Hot supplies** USDC into `CrownZkCredit`, then **draws $500k → Landing**.

## Live gate (ready)
| | |
|--|--|
| Attestation | **$1,000,000** · proof `0xe02936cc…7d9946` |
| Max draw (70%) | **$700,000** |
| Ask | **$500,000** |
| Buyer | Hot `0x6708…a7d1` |
| Credit | `0xc415…d936` |
| Landing | `0x5Adc…2357` |

## Blocker right now
Hot USDC ≈ **$1.61**. Self-advance at $500k needs **$500k USDC on hot** first (bridge/CEX/wire → hot).

## Fire (after hot funded)
```bash
# fund hot with 500_000e6 USDC, then:
KING_GO=1 FIRE_ZK_SELF=1 ASK_USDC=500000000000 \
  forge script script/FireZkSelfAdvance.s.sol:FireZkSelfAdvance \
  --rpc-url $RPC --broadcast --slow
```

## End state when fired
- Hot: −$500k USDC (buyer/lender inventory)  
- Credit: `supplyOf(hot)=500k`, `debtOf(hot)=500k`  
- Landing: +$500k USDC (cold spendable)  
- ZK rail proven end-to-end with King as both lender and borrower  
