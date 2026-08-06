# Dual-flash machine — fork results (King order)

**Bundler3 Base:** `0x6BFd8137e702540E7A42B74178A4a49Ba43920C4`  
**Balancer V2 classic vault:** not on Base (codesize 0). Dual flash uses **Morpho singleton** (USDC + WETH both flashable).  
**Contract:** `CrownDualFlashMachine`

## Honest Landing USDC nets (Base fork)

| Mode | What it does | Landing Δ |
|--|--|--|
| **A CREATE_IDLE** | flash USDC → supply RSS mkt → borrow → repay flash | **$0** |
| **B UNWIND** | flash USDC → repay king debt → withdraw supply → repay flash | **$0** |
| **C EQUITY_WETH** | LI.FI `initialCollateral` shape: 500 WETH → borrow 700k USDC to Landing | **+$700,000** |
| **D WETH_FLASH only** | flash WETH → coll → borrow to Landing (no equity to repay WETH) | **REVERT / $0** |

## LI.FI blueprint vs this board

Official recipe sizes Morpho borrow to **exactly** repay the USDC flash (**zero residual** by design) and requires **`initialCollateral` WETH**. It migrates a position; it does not mint wallet USDC from a matched RSS book.

Creating idle with the dual-flash itself (A) expands the matched book and leaves **$0** on Landing.

## Iterate next (on GO)

1. Wire Bundler3 `multicall` + PA `reallocateTo` + `morphoBorrow` when any vault maxIn > 0.  
2. Equity WETH path (C) — only live path that forked to **$700k on Landing**.

**Live fire:** not executed — A/B/D net zero; C needs WETH equity King does not hold on hot.
