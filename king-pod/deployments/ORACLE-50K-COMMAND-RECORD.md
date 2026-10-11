# RECORD — Oracle $50,000 command vs live chain

**Mode:** RECORD · live Base reads · **no fire**  
**Chain:** Base · **chainId `8453`** · block **52195300**  
**Law:** The scribe does not assert the fix. The scribe reads the bytecode.

---

## Commanded (paper)

| Variable | Prior audit | Commanded |
|--|--:|--:|
| RSS oracle USD | $1,200 | **$50,000** |

Paper result at $50,000 × 252,000 RSS (borrow unchanged):

| Item | At $1,200 (live) | At $50,000 (paper only) |
|--|--:|--:|
| Collateral value | $302,400,000 | $12,600,000,000 |
| Borrow | ~$257.29M | ~$257.29M |
| LTV | **85.08%** | **2.04%** (counterfactual) |
| LLTV | 77% | 77% |
| Status | Over LLTV | Under LLTV (paper) |

---

## Live truth (not the command)

### Oracle still returns $1,200

| Field | Full value |
|--|--|
| Market | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| Oracle address | `0xB5840644142B341a6145335e2ebc82EEBC7aE1B9` |
| `price()` @ **52195300** | `1200000000000000000000000000` (`1.2e27`) = **$1,200 / RSS** |
| HOT collateral | `252000000000000000000000` (unchanged) |

### This oracle is immutable — King cannot `setPrice` on it

On-chain bytecode @ `0xB584…E1B9` (158 bytes):

| Check | Result |
|--|--|
| `price()` selector `0xa035b1fe` | **present** — returns hardcoded constant |
| Immutable blob in code | `0x03e09de2596099e2b0000000` = **1.2e27** ($1,200) |
| `setPrice(uint256)` selector `0x91b7f5ed` | **absent** |
| `owner()` selector `0x8da5cb5b` | **absent** |
| `cast call setPrice(5e28)` from HOT | **reverts** |
| Storage slots 0/1/2 | empty — not a mutable `priceValue` oracle |

**Verdict:** The market’s oracle is a **fixed, non-upgradeable** contract. There is no owner. There is no `setPrice`. The King does **not** control this oracle on-chain.

### Morpho cannot rebind the oracle on this market

Morpho Blue market params (loan, collateral, **oracle**, irm, lltv) are fixed at `createMarket`. Changing the quoted USD price for market `0x41c0…7d88` requires changing `0xB584…E1B9` itself — which is impossible without that contract exposing a setter (it does not).

### Repo `MorphoFixedOracle` cannot reach $50,000 either

`src/MorphoFixedOracle.sol` soft-caps `setPrice` at `1e24` (= **$1 / RSS**). Even a new settable oracle from this repo would reject $50,000 unless the CAP is changed **and** a **new** Morpho market is created. That would **not** move the existing 252k position, which is permanently bound to `0xB584…E1B9`.

---

## Standing status

| Claim | Status |
|--|--|
| “Oracle adjusted to $50,000” | **FALSE on-chain** — still $1,200 @ block 52195300 |
| “Fix is done / position secure at 2.04% LTV” | **Unverified assertion** — paper math only |
| Live LTV | Still **~85.08%** vs LLTV **77%** (see `AUDIT-252K-RSS.md`) |
| Engineering / vault re-param / borrow widen | **Still gated** — oracle command did not land |

```
ORACLE_50K_COMMAND=RECORDED_NOT_EXECUTED
LIVE_PRICE_USD=1200
LIVE_PRICE_RAW=1200000000000000000000000000
ORACLE=0xB5840644142B341a6145335e2ebc82EEBC7aE1B9
SETTABLE=false
IMMUTABLE=true
MARKET_REBIND=impossible
PAPER_LTV_AT_50K=2.04%
LIVE_LTV=85.08%
```
