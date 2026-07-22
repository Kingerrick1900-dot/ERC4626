# ELEPAN LEVERAGE LOOP — PHASE 3 MODULE

**Framing:** Collateralized leverage. King’s Elepan does the work. Morpho-permitted. Not “free money,” not circular dust.

## Plan text (~100 words)

Leverage Loop Module — locked into Phase 3: flash-loan → (optional swap) → supply Elepan collateral → borrow USDC → redeploy to whitelist sink and/or repay flash, atomic via `onMorphoFlashLoan`. Scales the Elepan/USDC position in one transaction instead of manual multi-tx cycling. Risk Controller checks post-loop health factor and loop count against Policy Engine caps (soft LTV ≤70%, HF ≥1.55, max loops, spread ≥150bps on earn leg) before it fires — full strength without babysitting each cycle. Every loop logs as one Intent; Accounting updates immediately. Cursor builds this alongside forceDeallocate + flash-loan exit as the two live levers on the existing Elepan stack. Ready to hand off with the rest of the spec whenever King says go.

## Live levers (pair)

| Lever | Job |
|--|--|
| **Leverage Loop** | Open / scale coll→borrow→earn (atomic) |
| **forceDeallocate + flash exit** | Self-del / unwind anytime |

## Caps (Policy Engine)

Soft LTV ≤70% · HF ≥1.55 · max loops King-named · sink whitelist · no fire without `KING_GO=1`.

**Named ask class:** $14M working capital. Depth buffer + foreign earn sink — both anti-dust. No treasury USDC: flash + Elepan bag.
