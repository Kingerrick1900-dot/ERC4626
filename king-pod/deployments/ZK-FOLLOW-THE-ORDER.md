# ZK Advance — Follow the Order

**Buyer advances USDC against verified ZK proof.** Shield first. Real broadcast only.

## Sequence

1. Prepare calldata — see `BUYER-ADVANCE-CALLDATA.md`  
2. King gives **GO**  
3. Real buyer / King-controlled funded wallet broadcasts `advance`  
4. Confirm hash, USDC on Landing, kUSD to buyer  
5. Route to bills / KingVault  

## Door

CrownZkAdvance `0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B`  
Reverts if `!isProven(king)`. No mock buyers on live path.

On KING GO: scribe fires exact call (with `BUYER_KEY` or buyer self-sends) and reports hash immediately.
