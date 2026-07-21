# ENGINEER CREATE — GO (shelf)

**STATUS: BUILT — no broadcast until King FIRE.**  
Doctrine: create positions with RSS. No wait.

| # | Device | Contract | Fire |
|---|--------|----------|------|
| **1** | Crown CDP — RSS → mint **kUSD @ Fixed $1** | `CrownCdp` + `CrownKusd` | `FireCrownCdp.s.sol` |
| **2** | Bribe magnet — RSS budget → Aero bribe **or** direct LP rebate | `CrownBribeBudget` | `FireCrownBribe.s.sol` |
| **3** | King book — USDC suppliers chase RSS rebate; King borrows vs RSS | `CrownSupplyMagnet` | `FireCrownBook.s.sol` |

---

## 1 — CDP

Creates spendable **kUSD** from RSS. No Morpho idle.

```bash
KING_OK=1 FIRE_CDP=1 COLL_RSS=1000000000000000000000000 \
  forge script script/FireCrownCdp.s.sol:FireCrownCdp --rpc-url $BASE_RPC --broadcast
```

Default: 1M RSS coll → **700k kUSD** @ 70% LLTV.

---

## 2 — Bribe

Aero: gauge may be missing / RSS not whitelisted.  
**Direct rebate** still creates APR opportunity King controls.

```bash
KING_OK=1 FIRE_BRIBE=1 STOCK_RSS=500000000000000000000000 \
  forge script script/FireCrownBribe.s.sol:FireCrownBribe --rpc-url $BASE_RPC --broadcast
```

Optional: `DIRECT_REBATE_TO=0x… DIRECT_RSS=…` · `TRY_GAUGE=1` · `PUSH_BRIBE=1`

---

## 3 — King book

Venue: deposit USDC → get RSS rebate. King posts RSS → borrows USDC from **that** book.

```bash
KING_OK=1 FIRE_BOOK=1 \
  REBATE_RSS_PER_USDC=20000000000000000 \
  STOCK_REBATE_RSS=200000000000000000000000 \
  POST_COLL_RSS=2000000000000000000000000 \
  forge script script/FireCrownBook.s.sol:FireCrownBook --rpc-url $BASE_RPC --broadcast
```

Borrow fires after USDC hits the book: call `borrow(usdcAmt)` as King (or follow-up script).

---

## Live FIRE keys

| Env | Meaning |
|-----|---------|
| `KING_OK=1` | King read plan |
| `FIRE_CDP=1` / `FIRE_BRIBE=1` / `FIRE_BOOK=1` | Which device |
| `--broadcast` | On-chain |

**King: say FIRE 1 / FIRE 2 / FIRE 3 (or FIRE ALL) to broadcast.**
