# FIRE — China Connection (Phase 4 override)

**Mode:** FIRE · executed · float gate bypassed per King  
**Branch:** `cursor/fire-china-connection-4f7f` · PR #167  
**Doctrine:** Loan, don’t sell RSS. NFC = eUSD spend rail, not mint.

---

## Gas

| Wallet | Before → After |
|--|--|
| Polygon ops `0x3151…77dF` | ~8.63 POL → **~6.64 POL** |
| Base HOT | used for `setModules` only |

King cited 12.925 POL; live balance at fire was **~8.63**.

---

## Polygon (137) — LIVE

| Contract | Address | Tx |
|--|--|--|
| **RoyalCard** | [`0x9c0E36f7…Ce8D`](https://polygonscan.com/address/0x9c0E36f7f6A9194f781Bf2e2c23c48281a23Ce8D) | [`0x3598f754…f3a0`](https://polygonscan.com/tx/0x3598f754b9838c520239e4303d5eae2fa79e89f4d78e3a44cc7f5f9c4d46f3a0) |
| `setModules(PayAdapter, attest)` | — | [`0x7aa4f3e2…1b85`](https://polygonscan.com/tx/0x7aa4f3e2d64d9bd8559b141bd99498bb85ce5c47723a746d09c7ae24aade1b85) |
| Smoke `issue` card | cardId `0xc22409a0…8785` | [`0x022f5087…4bf2`](https://polygonscan.com/tx/0x022f5087c613e3d8146a000e84e85c2498d94df12fccbbfbd7ec7e37fb384bf2) |
| **CrownLakalaAcquiring** | [`0x0D85Af6f…6dFB`](https://polygonscan.com/address/0x0D85Af6f0Eb34dafd4EE349d8E562c1167DE6dFB) | [`0x8e935820…1b5a`](https://polygonscan.com/tx/0x8e9358204b3ec947b0824702a485ee9f10f299ce6a1cb8c16550d5364e7a1b5a) |
| **CrownLakalaCardBridge** | [`0x2039F833…B556`](https://polygonscan.com/address/0x2039F833Ad4928D17fe5f429b7dA9f290cbbB556) | [`0xe8db13b6…30f3`](https://polygonscan.com/tx/0xe8db13b6676491bf8299679228682f2d96041013ee8243212656cc61cfbd30f3) |
| acq `setModules` | attest + bridge | [`0x4bc1e276…e79f`](https://polygonscan.com/tx/0x4bc1e276e1731cc1be29c7e829745a157ba35cb60b7d3c3bffe6c126729ee79f) |
| bridge `wire` | RoyalCard ↔ acquiring | [`0xa7eafae8…09d9`](https://polygonscan.com/tx/0xa7eafae81f6df3461c18e3a19e95d5f6cadcf202c96b72bb67fcd4307ffb09d9) |
| `registerMerchant` CHINA-DESK-001 | desk=`0x3151…77dF` | [`0x4bb2b0df…d2a5`](https://polygonscan.com/tx/0x4bb2b0df90aa50537bc90ae028c527643f4efe38ddda5eef15055a5866a4d2a5) |
| `registerTerminal` SoftPOS-01 | — | [`0x035558de…6182`](https://polygonscan.com/tx/0x035558de801510a517103ea87233c914b0d98d866f5d676c8c6b432719ff6182) |
| PayAdapter `setMerchant(desk)` | [`0x2FAEd8D8…f629`](https://polygonscan.com/address/0x2FAEd8D83f61d157419b33F7938aDCd9F2c4f629) | confirmed `merchant=true` |
| OpenMoney `setMerchant(desk)` | [`0xe3e165C8…7a7c`](https://polygonscan.com/address/0xe3e165C8823d35966C85353D5A4f257623417a7c) | [`0xfa5748fb…b31d`](https://polygonscan.com/tx/0xfa5748fb1031720b9b8655f1f5d80b28e379126851e7fec8d9aa4801bf11b31d) |

### IDs

```
mercId  = keccak("CHINA-DESK-001") = 0x82da7f8e…7ed2
termNo  = keccak("TERM-SOFTPOS-01") = 0x213822f1…396c
cardId  = keccak("CN-SMOKE-001")   = 0xc22409a0…8785
```

---

## Base (8453) — LIVE wire

| Action | Result |
|--|--|
| RoyalCard `0xcE228F10…A85c` `setModules(PayAdapter, attest)` | [`0x359467d3…7b6c`](https://basescan.org/tx/0x359467d38a2f69a401ce9d745f9d8a4a675679c072f2f31f452652f263fd7b6c) |
| spendVault | `0xA6D5C525…f3B1` (PayAdapter) |
| attest | `0xe3Be837a…14E7` |

Note: Base RoyalCard bytecode predates merchant-gate; Polygon RoyalCard enforces `PayAdapter.merchant`.

---

## China desk

**Channel OPEN** — see `CHINA-DESK-CHANNEL.md`  
CN engineers: physical ISO7810+SE spec + parallel-chain testnet (eUSD only).

---

## Still true

- No RSS sold · no RSS minted from NFC  
- Lakala = Crown-*class* only  
- Physical SE manufacturing = CN Week-0 deliverable  
- Rotate POLY / HOT after fire window  

---

## One-block

```
FIRE=china-connection-phase4
POLY_RoyalCard=0x9c0E36f7…Ce8D
POLY_Lakala=0x0D85Af6f…6dFB
POLY_Bridge=0x2039F833…B556
PayAdapter+OpenMoney merchant=desk 0x3151…77dF
BASE_RoyalCard spendVault=PayAdapter
DESK=OPEN · PHYS+TESTNET to CN
DOCTRINE=loan-RSS · NFC=eUSD-spend
```
