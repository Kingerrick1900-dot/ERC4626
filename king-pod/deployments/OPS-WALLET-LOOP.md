# OPS WALLET — LOOP ONLY

**Carry / scaler / dust ops run from loop — not hot.**

| Role | Address | Use |
|--|--|--|
| **Loop (OPS)** | `0x8d3cfbFc6A276f118579517E4d166e94C66F8585` | Fund ETH here. `CarryLoopScaler` signer. |
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | Morpho PoD / curator owner. Has contract code — **do not** treat as ETH receive ops wallet. |
| KingVault | `0xA1aFcb46a64C9173519180458C1cF302179c832a` | USDC fee trough only. |

## Mistake (2026-07-18)
Carry/scaler was fired with hot’s key. ETH on hot was swapped into cbETH collateral under **hot’s** Morpho position. Loop ETH was left untouched. Loop→hot top-ups failed because hot is EIP-7702 delegated (`ef0100…`) — not a plain EOA receive path, and RPCs reject gapped/parallel nonces on delegated accounts.

## Unwind (done 2026-07-18)
Stuck hot cbETH carry closed → ETH sent to **loop**.

| Step | Result |
|--|--|
| yRSS withdraw + Morpho repay | debt cleared (`0x80c122bf…`) |
| withdrawCollateral (forge) | OOG @ 97k gas — **failed** |
| withdrawCollateral (cast, 250k gas) | `0x6cc5964c…` ok |
| Aero cbETH→ETH | `0x3ecc13a2…` ok |
| ETH → loop | `0x949282ce…` — **~0.00398 ETH** |

**Final:** Morpho cbETH pos = 0. Loop ETH ≈ **0.00465**. Hot keeps ~0.00015 ETH gas + ~$1 USDC floor.

Hot ops rule: **one tx at a time**, gas limit padded (≥1.5× estimate). Do not forge-broadcast multi-tx batches against hot.

## Fix
`CarryLoopScaler` now `require(signer == loop)`. Fund **loop** for future carry laps.

## HALTED (2026-07-18)
King stopped carry. Loop Morpho flat. ETH + $1 USDC parked on loop. Scaler requires `CARRY_ARMED=1` to fire again.

## Chief failure (own it)
~$7–9 ETH carry was a **dead mission** (fees + gas + borrow &gt; any dust yield). Chief should have refused before broadcast. Standing gates: `deployments/CHIEF-ECONOMIC-KILL-GATES.md`. Scripts now revert `DEAD_SIZE_*` / `DEAD_GAS_TAX` under min size.
