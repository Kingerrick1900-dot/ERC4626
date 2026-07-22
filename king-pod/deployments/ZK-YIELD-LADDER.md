# ZK Yield Ladder — multi-pool / multi-chain playbook

## Thesis
1. **One wallet-bind proof** (kUSD+RSS@$1 ≥ $700k, sizes private)  
2. **Same Groth16 proof** verifies on every chain where the wallet verifier+gate are deployed  
3. **Small draws** from each chain’s credit pool \(L\) (0% Kingdom borrow)  
4. **Park draws in yield vaults** (Steak / Gauntlet / local ERC4626)  
5. **Harvest → deepen \(L\) or next rung**  
6. **Refresh proof** as hot capital grows (`refresh-wallet-proof.sh`)

## LIVE Base (armed this round)
| | |
|--|--|
| Gate | `0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579` |
| Prior Credit B | `0x5C60a79b02c1907d5d23aEBfe259c5bb9116798d` |
| Ladder Credit + YieldLadder | see fire logs / `FireZkYieldLadder` |

## Draw policy
- Tranche cap per step: **≤ $500** (raise by King order)  
- Never draw to spend — draw → allocate → harvest → deepen/reinvest  
- Cap still \(\min(0.7\times T,\ |L|)\) per chain

## Cross-chain fan-out
```bash
# After deploying verifier+gate+credit on OP/ARB/ETH with SAME VK:
GATE_BASE=0xFfC9... GATE_OP=0x... GATE_ARB=0x... \
  bash king-pod/script/fanout-wallet-proof.sh
```
Proof file: `zk/proofs/wallet_proof_solidity.json` — **reuse**, do not invent witnesses.

## Scale proof
```bash
GATE=0xFfC9... bash king-pod/script/refresh-wallet-proof.sh
```
Pulls live hot kUSD+RSS; refuses if under threshold; updates commitment on-chain.

## Blocker (honest)
Each chain’s \(L\) needs **system USDC supply**. Empty \(L\) ⇒ `maxBorrow=0`. Ladder is the machine; liquidity is the fuel.
