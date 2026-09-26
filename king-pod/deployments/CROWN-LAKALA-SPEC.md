# Crown Lakala-class Acquiring — build to perfection

**Status:** Spec + contracts + unit tests · Crown-original  
**Doctrine:** Lakala-*class* merchant acquiring surface. **Not** a Lakala patent fork, API clone, or binary port.

---

## Why “Lakala-class”

China desk merchants expect a familiar acquiring shape:

| Familiar concept | Crown surface |
|--|--|
| `mercId` | `bytes32` merchant id |
| `termNo` | `bytes32` terminal under merchant |
| 被扫 micropay | `micropay` / `micropayFromCard` |
| 主扫 preorder | `preorder` + `capture` + `close` |
| refund / revoke | `refund` / `revoke` |
| settle ledger | `settle` / `settleBatch` + MDR |
| trade query | `tradeQuery` |

Pay rails are Kingdom-native: **NFC · RoyalCard · QR_CROWN · DIRECT** — not WeChat/Alipay clones.

---

## Contracts

| File | Role |
|--|--|
| `king-pod/src/china/CrownLakalaAcquiring.sol` | Merchant/terminal lifecycle, micropay, preorder, refund, settle, MDR, borders |
| `king-pod/src/china/CrownLakalaCardBridge.sol` | RoyalCard → acquiring micropay bridge |
| `king-pod/src/royal/RoyalCard.sol` | NFC card daily-limit spend rail (Phase-4 preview) |
| `king-pod/kar/nfc_cosign.md` | Off-chain NFC cosign stub |

---

## Lifecycle

```
King registerMerchant(mercId, operator, settleWallet, mdrBps)
  └─ operator registerTerminal(mercId, termNo)

Payer path A — micropay (被扫-class):
  approve payToken → micropay(mercId, termNo, outTradeNo, amt, payMode, receipt)
  → escrow + pendingSettle[merc] += amt - MDR

Payer path B — preorder (主扫-class):
  operator preorder → payer capture(receipt) → same ledger
  unpaid → operator close

Payer path C — RoyalCard:
  acquiring.setModules(attest, bridge, mdr)
  bridge.wire(royalCard, acquiring, requireRoyalSpend?)
  payer approve bridge → payWithCard(...)

Refund: operator refund/revoke → claw pendingSettle + protocolFees → payer
Settle: operator/settleWallet/king settle(mercId) → settleWallet
King: sweepProtocolFees
```

---

## Fee (MDR)

- `defaultMdrBps` on deploy (e.g. 100 = 1%)
- Per-merchant override via `mdrBps` (0 = use default)
- Hard cap **500 bps (5%)**
- Fee held in `protocolFees` until King sweep

---

## Gates

| Gate | Behavior |
|--|--|
| `paused` | Blocks pay/refund/settle paths |
| `merchant.frozen` | Blocks new capture + settle |
| `terminal.active` | Must be true for pay |
| `attest.bordersSecure()` | Optional ZK borders |

---

## Build today vs later

| Today | Later (Phase 4 fire) |
|--|--|
| Contracts + Foundry suite | Base/Polygon mainnet deploy |
| Spec + KAR NFC cosign stub | SoftPOS / SE vendor + China desk |
| Local mint/pay/settle smoke | Live eUSD / USDC payToken + attest wire |

---

## One-block

```
CROWN_LAKALA=kingdom-original acquiring (mercId/termNo/micropay/settle)
NO lakala-patent-fork
CODE=king-pod/src/china/CrownLakalaAcquiring.sol
BRIDGE=king-pod/src/china/CrownLakalaCardBridge.sol
CARD=king-pod/src/royal/RoyalCard.sol
TEST=king-pod/test/CrownLakala.t.sol
MFG=Phase4 after float+China GO
```
