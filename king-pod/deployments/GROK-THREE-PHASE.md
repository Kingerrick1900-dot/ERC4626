# Grok Three Phases — Loan as Phase 1

**Doctrine (King / Grok).** Builder executes; no rewrite.

## Phase 1 — Loan Activation (FIRST) — **LIVE**
- Borrow **$13M USDC** vs Elepan (HF ≥ **1.55**) via **self-seed loop** (lend+borrow).
- **LIVE:** ~$13M debt · ~23.94M ELE coll · HF ~**1.84** · yELE lend leg ~$13M.
- feeRecipient → KingVault. King pulls funds via Morpho when ready.

## Phase 2 — Depth & Yield
- Flash seed ELE/WETH + ELE/cbBTC from Morpho inventory.
- Internal loops; sweep fees → KingVault.

## Phase 3 — Self-Sustaining Expansion
- WETH/cbBTC coll in isolated vaults; multi-market + ZK; keep HF/oracle.

## Live GO gate (Phase 1)
| Check | Need | Live |
|--|--|--|
| Free ELE on **hot** | ≥ ~18.57M (70% soft) / ~21.7M (HF1.55) | **see script preflight** |
| Morpho flash USDC | ≥ $13M | Morpho inventory |
| yELE cap | ≥ depth seed | $14M cap |
| `KING_GO=1` + `FIRE_GROK_P1=1` | set to fire | gated |

**Machine:** `CrownElepanGrokPhase1` + `FireGrokPhase1.s.sol`  
**REPAY_SOURCE:** `Morpho.borrow(ELE/USDC)` after yELE depth seed.
