# DEEPSEEK WHALE PLAYBOOK — Oracle + Cross-Flash Treasury

**Doctrine:** King owns the oracle. Morpho sells the market primitive, not the price. Use it.  
**Score:** Hard USDC in KingVault. Debt held against RSS. Not circular theater that repays itself to zero.

---

## Machine (what DeepSeek described / we engineer)

### Pieces
| Piece | Role |
|--|--|
| **Oracle** | MorphoFixedOracle @ **$1** live; EliteOracle (uncapped) for new markets |
| **RSS** | Collateral engine (~18.5M posted + free RSS) |
| **LiquiditySink** | Separate address that **supplies** USDC (not the borrower) |
| **King** | Posts RSS, **borrows**, holds debt |
| **KingVault** | Receives borrow USDC and **keeps it** |
| **Morpho flash** | Cross-flash seed from global Morpho USDC float (~$190M+ on Base) |

### Why two addresses
Supplier ≠ borrower. Sink holds supply shares. King holds debt + RSS. Vault holds cash.  
Same pattern attackers use when splitting roles — we use it as **issuer treasury engineering**, not to drain foreign vaults.

### Atomic Cross-Flash fill
```
1. Morpho.flashLoan(USDC, S)                         // cross-flash from other markets' float
2. LiquiditySink.supply(S) → RSS/USDC market          // seed float into OUR book
3. King already has RSS collateral @ $1 oracle
4. Morpho.borrow(S, onBehalf=King, receiver=KingVault) // LOAN to treasury — HOLD
5. Repay flash from a REAL repay rail (below) — NOT by emptying the vault
```

### Repay rails (pick one — this is the whale part)
| Rail | How flash gets repaid without zeroing vault |
|--|--|
| **R1 — External seed** | Separate USDC pays flash; vault keeps full borrow |
| **R2 — PA inbound** | `reallocateTo` brings outsider USDC first; borrow that; flash optional |
| **R3 — Profit loop** | Mid-tx Strike/arb profit ≥ S; repay flash; vault keeps borrow + profit |
| **R4 — Desk inventory** | Desk holds USDC fill; RSS slice settles flash repay (elite one-tx style) |

**Forbidden:** supply S → borrow S to vault → pull S from vault to repay flash. Net $0. That is YouTube self-lend cosplay. We already did that as PoD demand signal — it is **not** the treasury fill.

---

## Live board (inputs to the machine)
- Oracle: **$1**
- PoD book: **~$9.25M** util 100% (demand magnet)
- King RSS collateral: **~18.5M** → ~**$5M borrow headroom** at HF~1.54
- CrownSpoilFire: armed
- yRSS PA: armed (cbBTC/WETH/RSS)
- KingVault: **~$8.12**

---

## Execute order (aggressive)
1. **Ship `CrownCrossFlash`** — dual sink + borrow-to-vault + flash callback; repay rail explicit.
2. **Deploy MorphoEliteOracle** — uncapped `setPrice` for any new market King opens.
3. **Wire repay rail R3 first** — every Strike/arb dollar can repay a cross-flash and leave vault borrow intact when sized right.
4. **Wire R2** — SpoilFire already; auto-borrow idle the second it appears.
5. **Never** call PoD circular open a “vault fill.”

---

## Success
KingVault USDC ↑ while Morpho debt ↑ and RSS stays posted.  
That is loan + token. That is the playbook.
