# OPS WALLET — LOOP ONLY

**Carry / scaler / dust ops run from loop — not hot.**

| Role | Address | Use |
|--|--|--|
| **Loop (OPS)** | `0x8d3cfbFc6A276f118579517E4d166e94C66F8585` | Fund ETH here. `CarryLoopScaler` signer. |
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | Morpho PoD / curator owner. Has contract code — **do not** treat as ETH receive ops wallet. |
| KingVault | `0xA1aFcb46a64C9173519180458C1cF302179c832a` | USDC fee trough only. |

## Mistake (2026-07-18)
Carry/scaler was fired with hot’s key. ETH on hot was swapped into cbETH collateral under **hot’s** Morpho position. Loop ETH was left untouched. Loop→hot top-ups failed because hot is not a plain EOA.

## Fix
`CarryLoopScaler` now `require(signer == loop)`. Fund **loop** for future carry laps.

```bash
# Fund: send ETH to 0x8d3cfbFc…8585
LOOP_PRIVATE_KEY=… ETH_IN=… LOOPS=1 \
  forge script script/CarryLoopScaler.s.sol:CarryLoopScaler --rpc-url $BASE_RPC_URL --broadcast
```
