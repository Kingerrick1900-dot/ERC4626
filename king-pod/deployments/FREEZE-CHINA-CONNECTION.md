# FREEZE — China Connection (Override)

**Mode:** FREEZE → then FIRE · **King override:** bypass ~$375M float gate  
**Branch:** `cursor/fire-china-connection-4f7f`  
**Recorded:** 2026-09-26  
**Doctrine unchanged:** Loan, don’t sell RSS. China/NFC = **spend rail**, not mint rail.

---

## Order (verbatim intent)

1. Fork the Lakala NFC rail → **Crown Lakala-*class*** (not patent copy). Deploy / wire `RoyalCard.sol`.  
2. Wire Polygon `CrownPayAdapter` to commerce rails using available POL gas.  
3. Open China desk channel — CN engineers: physical card spec + parallel-chain testnet.  
4. Keep doctrine: RSS stays collateral; cards spend **eUSD**, never mint RSS.

```
OVERRIDE=Phase4 China GO without float gate
BUILD=bridge with what King holds (POL gas + live rails)
RESULT=Royal Card concept → code + live wire today
```

---

## Honest inventory (before fire)

| Asset | Live |
|--|--|
| Polygon ops (`POLY_KEY` = `0x3151…77dF`) POL | **~8.63** (King cited 12.925 — use live balance) |
| Base HOT ETH | **~0.00015** (enough for cheap `setModules`) |
| Base RoyalCard | **LIVE** `0xcE228F10…A85c` · spendVault=0 · attest wired |
| Base PayAdapter | **LIVE** `0xa6d5c525…f3b1` |
| Polygon PayAdapter | **LIVE** `0x2faed8d8…f629` · owner=POLY |
| Polygon OpenMoney | **LIVE** `0xe3e165c8…7a7c` |
| Polygon eUSD | **LIVE** `0xd8a639bb…af50` · supply 1e6 eUSD |
| Polygon attest | `0x00cAe93d…7211` · `bordersSecure=true` |
| yRSS / PARK gold rail | ~$220.6M matched — **not** China spend fuel |
| RSS doctrine | Loan ≠ sell · NFC does not mint RSS |

**Float gate:** overridden by King. War-chest capacity still ≠ Circle. Bridge fires on POL + existing commerce contracts.

---

## Freeze checklist (must hold during fire)

- [ ] No RSS market sell / no RSS mint from NFC path  
- [ ] Lakala = **class** surface only (mercId/termNo/micropay) — no patent/API clone  
- [ ] PayAdapter merchants = eUSD spend only  
- [ ] Physical SE seeds never on-chain  
- [ ] Parallel chain = **testnet first** (CN brief)  
- [ ] Rotate POLY/HOT keys after fire window  

---

## Fire sequence (when ready)

| Step | Action |
|--|--|
| F1 | Restore `CrownPayAdapter` source + China wire script |
| F2 | Base: `RoyalCard.setModules(PayAdapter, attest)` |
| F3 | Polygon: deploy `RoyalCard` + optional Lakala acquiring; `setModules(PayAdapter, attest)` |
| F4 | Polygon: `PayAdapter.setMerchant` + `OpenMoney.setMerchant` for China desk merchant |
| F5 | Publish `CHINA-DESK-CHANNEL.md` — physical card + testnet orders to CN |
| F6 | Record txs in `FIRE-CHINA-CONNECTION.md` |

---

## One-block

```
FREEZE=china-connection-override
BYPASS=375M-float-gate
GAS=POLY~8.63 · BASE_HOT~0.00015ETH
DOCTRINE=loan-dont-sell-RSS · NFC=spend-not-mint
NEXT=FIRE-CHINA-CONNECTION
```
