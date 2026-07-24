# KING SETUP — READ THIS FIRST (not yRSS)

**Scribe / Grok / agent correction:** King is **not** running a yRSS loan.  
yRSS is a **legacy dust vault** (~$0.35 in BRETT). It is **not** the credit path.

---

## Actual setup (current)

| Layer | What it is |
|--|--|
| **Loan** | Morpho Blue **ELE/USDC** `0xa4ec5271…da53fc` · 77% LLTV |
| **Collateral** | **Elepan** posted on hot (Morpho `supplyCollateral`) |
| **Draw** | Morpho `borrow(assets, 0, hot, Landing)` — any portion · KEEP on Landing |
| **Pack** | ZK gate attest on hot — packing only, **not** the loan |
| **Exit** | Morpho flash **pre self-liq** → ELE/USDC surplus to Landing |
| **Forbidden** | Recycle Landing USDC into yELE / yRSS / same-market loop |

Contracts (prep): `CrownElepanKeepDraw` · `CrownElepanPreSelfLiq` · `CrownMorphoZkPack`

---

## What yRSS is (and is not)

| | |
|--|--|
| **Is** | Old MetaMorpho USDC vault King still owns; fee 10% → Landing; TVL dust |
| **Is not** | The Kingdom loan, the ELE credit engine, or where KEEP goes |
| **Do not** | Tell King to “use yRSS” / reallocate yRSS as the scale path for this loan |

Same for **yELE**: unwound / dust. Not the live borrow book.

---

## Passive (on this setup)

Fees/skims to **Landing** around the Morpho ELE book and optional side rails — not “earn via yRSS allocation.”  
yRSS fee line is incidental legacy, not the product.

---

## One line

**Morpho Elepan loan + ZK pack → Landing KEEP. Not yRSS.**
