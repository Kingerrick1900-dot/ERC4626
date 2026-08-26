# KINGDOM FEDERAL RESERVE — BACKING SEAL (RSS ONLY)

**Branch:** `cursor/crown-fleet-auto-4f7f`  
**Mode:** FREEZE · **No loans** · **RSS only** (no Ele)

## Two phases — both NOW

### Phase 1 — Back the float
`CrownBackingScribe.seal()` attests:
- gUSD total == eUSD locked in wrapper (1:1)
- RSS Morpho books (eUSD/$50k + gUSD/$50k) supply/borrow/idle + King RSS coll
- USDC borrow capacity on RSS/USDC/$1200
- Notes `canIssue` · FxEngine `armed=false`

### Phase 2 — Seal cold rails
`railsCold()` checklist: notes OK · engine cold · capacity ≥ $10M · ready checklist true.  
Arm = King-only later. **Not fired here.**

## Live rails

| Piece | Address |
|--|--|
| **Backing Scribe** | _fill after fire_ |
| Notes | `0xD432543C3ef51214c2BD4D79B4a387e2f900e1d3` |
| FxEngine | `0x821a54725370EB11155F25FD0A877540cA7D4099` armed=false |
| 8020+Fx | `0x308a9b23941927a86e2245Bc122b691E4277910E` |
| eUSD AMO | `0x8960BdbE760E6C90c53a912063170a2Efb1df4Ed` |
| gUSD AMO | `0x380E199070A329ADefADB43F1932Da301FFC767d` |
| RSS | `0x7a305D07B537359cf468eAea9bb176E5308bC337` |

## Auth checklist (arm later — not now)
1. Morpho `setAuthorization(fxEngine, true)` from HOT  
2. RSS/USDC market idle ≥ fill size  
3. `fxEngine.setArmed(true)`  

## Doctrine
RSS = Fed gold. Print float. Gate on capacity. Settle on demand. Loan don’t sell. Engine cold until King.
