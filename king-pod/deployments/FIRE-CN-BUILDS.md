# FIRE — CN Builds

**Mode:** FIRE complete · Cursor-ready scaffolds live  
**Branch:** `cursor/fire-cn-builds-4f7f`  
**Doctrine:** Loan ≠ sell RSS. Crown-original class only — **no** Lakala/CIPS/CN-L1 patent forks.

Tests: `CnBuildsTest` **4/4 PASS**

---

## Live addresses

### Polygon (commerce trio)

| Surface | Address | Wire |
|--|--|--|
| **CrownParallelSettlement** | `0xAC825E8E235B4F3C9191281C8223D8E1e7834C07` | attest `0x00cAe93d…7211` · kar/desk `0x31511861…77dF` |
| **CrownRoyalCardNFC** | `0x00D102B6FAB80638Beb0D68cEa20FDb63CCECFaF` | pay `0x2FAEd8D8…f629` · attest `0x00cAe93d…7211` |
| **CrownCIPSCorridor** | `0x5440572c77bc999D40640AfBaAcfA54504B8ccd7` | openMoney `0xe3e165C8…7a7c` · attest `0x00cAe93d…7211` · `rateUsdcPerEusd=1e6` |

Forge script also redeployed Parallel/NFC twins (`0x5fdec721…`, `0xcc3321a0…`) — **canonical = table above**.

### Base (stealth firepower)

| Surface | Address | Status |
|--|--|--|
| HuntRouter | `0xc4c63f8CD4182452f665e338F87b4d31aeF04516` | live |
| **CrownStealthRouter** | `0x4dc7aD7b08Ce286b208401ECfc926B98728bC28c` | attest Base ZK · **hunter=true** |
| bot1 | `0xCe1DDaD07AC32E4210d783e8570e5e6f0E9c8641` | stealth bot=true · **hunter=true** |
| bot2 | `0xA7f4248759C71E80F6Ba7d42d49eb156F18192Ad` | stealth bot=true · **hunter=true** |
| bot3 | `0xA1c7547C0A7EAc7d5E20BafE2FF6b698Ebff9F09` | stealth bot=true · **hunter=true** |
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | sweep target · Hunt owner |

---

## What each does

1. **ParallelSettlement** — multi-rail clear ledger (chain ids in/out) for CN desk posts → settle eUSD.
2. **RoyalCardNFC** — offline signed-tap cache → later PayAdapter settle (Crown cache **class**, not patent).
3. **CIPSCorridor** — invoice → eUSD capture → USDC out at 1:1 USD (`rateUsdcPerEusd=1e6`).
4. **StealthRouter** — commit-reveal intent → HuntRouter Morpho flash → sweep HOT; ZK `bordersSecure` gate.

---

## Ops notes

- Live PayAdapter lacks `setPuller` — NFC uses merchant/fallback path.
- Bot `setHunter` needed elevated Base tip after HOT gas top-up (EIP-7702 HOT; plain 21k transfers fail).
- Stealth is hunt-armed; bots fire via Stealth commit→reveal or direct Hunt as hunters.

---

## One-block

```
FIRE=cn-builds
POLY=parallel+nfc+cips-wired
BASE=stealth+3bots-hunter
TEST=4/4
NO=patent-fork
DONE=true
```
