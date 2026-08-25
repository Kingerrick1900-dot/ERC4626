# KING ERRICK V4 — COMPLETE

**Branch:** `cursor/gusd-v4-brand-4f7f`  
**Fired:** 2026-08-25  
**Sequence:** gUSD brand → sync settlement → multi-chain mesh → **$50k oracle**

---

## Live addresses

### Base (8453)

| Piece | Address |
|--|--|
| **gUSD** | `0x319A49BB274A826F889C6e7221FA82f24ac8bc5d` |
| **8020 sync** | `0x0064532B41Ddd8961E6a6c528c70DB56efb13305` |
| **ZK mesh** | `0x9702dd14e567BBf095D43c4Bbfe7D0ec2c79dB5a` |
| **8888 elephant** | `0x98A93dF29eFf6d131d0421C2fEfBC36D3D4693b2` |
| **$50k oracle** | `0x264f7AfB8f12028345B87FD5E58F2CF444EebA90` |
| **RSS/eUSD/$50k market** | `0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b` |
| Base PSM (seeded) | `0xF7337A26d9456e42a36531A12036A4556EF1F987` |

### Scroll (534352)

| Piece | Address |
|--|--|
| **gUSD** | `0x7387f89cCBe3B5E852FA579b029c279747380a01` |
| **8020 sync** | `0x5578bA90b4223bdF6c296dAe9348A2Ca43116cCD` |
| **ZK mesh** | `0xd9057bdf874aAc17E244e2853884c027071f4Bd1` |
| Gold PSM | `0x064489A287448674AA1dC6fb740d2F518CBA75dA` |

---

## Proven on-chain

1. **Brand:** Base 11,000 gUSD + Scroll 1,000 gUSD wrapped from eUSD  
2. **Sync settlement:** Base PSM seeded (~$2.51) → **1 eUSD → 1 USDC** via 8020 `redeemSync` (tx `0x81477059…`)  
3. **Mesh:** Base + Scroll mesh contracts wire Bound / Elepan / Settlement gates; `meshProvenHot=true` on Base  
4. **8888:** Elephant intent contract live vs settlement gate `0x7c48a7fA…`  
5. **Oracle step-up:** Morpho market created at **$50,000 / RSS** (new book — $1200 AMO untouched)

---

## Physics note

- V1 $1200 AMO book still live (~91.8M eUSD idle)  
- V4 $50k market is a **new** Morpho book — migrate RSS when King orders  
- Max borrow at 50k / 77% LLTV on 9.6M RSS ≈ **$369.6B** theoretical — own gates enforce price

No weak plans. Sequence finished.
