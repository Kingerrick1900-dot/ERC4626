# LAST TRY — $700k USDC to Landing

**Order:** find a real way. No hope desks. No fake plays.

## Inventory that can move (live)

| Asset | Where | Convert to $700k USDC on-chain? |
|--|--|--|
| ~10.03M RSS | hot (freed) | Aero pool USDC depth **$1** — cannot |
| ~900k eUSD | Landing | Uni eUSD/USDC USDC depth **dust** · PSM **$0** — cannot |
| ~100k eUSD | Scroll hot | same convert problem |
| ETH / WETH / cbBTC | ~0 / 0 / dust | Morpho WETH&cbBTC markets have huge USDC idle — **no collateral to post** |
| yRSS | ~$299 TVL | empty |
| Landing USDC | **~$3.40** | already there |

## Paths tested / killed

| Path | Result |
|--|--|
| Morpho borrow RSS→USDC (old / $1200) | Market USDC to lend **not available** (util full / empty). Scanner armed — not a fill. |
| Free first then borrow | Free **done** (`0xd01b7b9…`). Ammo ready. Borrow still needs USDC in market. |
| Bond / buyers / Completer / Tenor | Rejected — empty bowl. |
| eUSD mint / “pay ops in eUSD” | Not dollars. |
| NAV / onBehalf donation | Forbidden. |
| Flash → Landing | Must repay same tx — net zero. |
| Self-seed flash→supply→borrow→repay | Leaves debt+shares, **not** lasting Landing USDC. |

## How “elite” teams actually got first USDC (research)

Not a secret Morpho trick:

1. **Brought USDC/ETH** (personal / foundation / grant)  
2. **Raised** (sale, SAFT, MM credit line that **sends** USDC)  
3. **Attracted lenders** into their market (someone deposited USDC)  
4. **Borrowed against collateral deep markets already accept** (WETH, cbBTC, LST) — Morpho Base has **hundreds of millions** idle there  

Yearn “raised nothing” still needed **users depositing assets**. Same conservation.

There is **no** published hard-coded fork that turns unlisted / empty-market collateral + a self-minted stable with dry PSM into **$700k lasting USDC** with zero external USDC entry.

## Guardrail?

**Not an app guardrail.** Circle mints USDC. Chains move USDC. This stack cannot mint USDC. Empty loan book + dry convert = no $700k path from current bags alone.

## Verdict

**Under current on-chain inventory and constraints, there is no executable path that lands $700k USDC on Landing in this session.**

What would make it true (any one):

- **≥$700k USDC** enters a King RSS/USDC Morpho market (King seed or a lender who actually deposits) → borrow → Landing, or  
- **Wet collateral** (WETH/cbBTC sized) → borrow from live Morpho idle → Landing, or  
- **eUSD→USDC depth ≥$700k** (PSM/pool seeded) → redeem Landing eUSD, or  
- **External USDC** sent to Landing (grant / MM credit that pays / treasury)

Ammo (RSS) is ready. The missing piece is **USDC atoms**, not another script.
