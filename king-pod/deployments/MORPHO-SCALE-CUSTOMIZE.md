# Legacy inventory note — yRSS (NOT the King loan)

**Correction:** This file is **not** the Kingdom credit setup.  
Operating loan = **Morpho ELE/USDC + ZK pack** → see `KING-SETUP.md`.

yRSS `0xF80C…D525` is a **legacy** MetaMorpho USDC vault King still controls. Do not scribe “King uses yRSS” as the loan.

---

## Live yRSS snapshot (dust only)

| | |
|--|--|
| TVL | ≈ **$0.35** |
| Where | ≈100% **BRETT** market |
| cbBTC / WETH | Caps on, **$0** allocated |
| Fee | 10% → Landing |
| ELE market | **Not listed** |

---

## If ever touching yRSS later

Optional curator hygiene only (BRETT → cbBTC/WETH) when TVL is real — **orthogonal** to the ELE Morpho loan.  
Never route Landing KEEP into yRSS/yELE.

`FireYrssCuratorPrep` = report/gated legacy tool. Default **no broadcast**.
