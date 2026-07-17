# LOAN + TOKEN WIN PLAN

## The win
King’s **RSS token** = Morpho collateral.  
Morpho **loan** = USDC borrowed to vault.  
**Debt stays.** RSS stays posted. Vault holds hard USDC.  
Not a sale. Not elite-close (that zeros debt and eats fill). Not dust loops.

## Pieces already on the board
| Piece | Fact |
|-------|------|
| TOKEN | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` — **~18.49M free** on King hot (live) |
| Oracle | `0x284E…7D2e` — **$0.05 / RSS** (live) |
| Collateral book | 18.49M × $0.05 ≈ **$924.7k** |
| LLTV | **77%** |
| Max loan | ≈ **$712k** against that RSS book |
| LOAN market | Morpho Blue `0x40ac…b794` (RSS collateral / USDC loan) |
| Vault | `0xA1aF…832a` |
| King hot | `0x6708…a7d1` |
| Live supply today | **7 wei** — borrow blocked until seed **S** is in the market |

## One fire (loan + token)
1. **Seed loan float S** — USDC `supply` into Morpho market `0x40ac…b794` (onBehalf = liquidity side).
2. **Post TOKEN** — King `supplyCollateral` RSS (size for target B / HF).
3. **Take the LOAN** — `borrow(B)` with `receiver = vault`.
4. **HOLD** — do not repay, do not elite-close, do not sell the posted RSS.
5. End state: vault **+B hard USDC**, Morpho debt **B**, RSS locked as collateral, HF ≥ floor.

## Size card (from `powerborrow-sim` — if seeded)
| Seed S | Borrow B → vault | HF | Live now |
|--------|------------------|----|----------|
| $100k | ~$100k | ~7.12 | No (market empty) |
| $250k | ~$250k | ~2.85 | No |
| $500k | ~$500k | ~1.42 | No |
| $700k | ~$700k | ~1.02 | No — knife edge |
| Max ~$712k | ~$712k | ~1.00 | No — wall |

Safe working band: **S = B ≤ $500k** (HF ≥ ~1.4). Knife-edge $700k only if King orders it.

## What “win” means here
- Vault balance goes up by **B**.
- Token (RSS) is the engine that **qualifies** the loan.
- Loan is real Morpho debt against that token — not theater, not flash that must repay same tx into zero.

## Gate (one line)
Market supply must be ≥ B before step 3. Empty book = no loan. Seed S first, then fire borrow to vault.

## Do not mix in
- Elite flash close / desk fill (different machine — debt 0, fill consumed)
- Self-lend flash open (builds circular book, **$0** to vault)
- Public depositor pitch as the plan title
- Dust recycle called growth

## Fire rule
No broadcast until King greenlight. Size = King’s number. Scribe runs seed → collateral → borrow(vault) only.

## Script hook
`powerborrow_sim.py` + Morpho calls:
`supply(S)` → `supplyCollateral(RSS)` → `borrow(B, receiver=vault)`.
