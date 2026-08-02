# Where the $14M is — and how $500k comes out

## Straight talk

Morpho **did** let you borrow ~$14M. That USDC was real for one moment — then the self-seed path **deposited it into your own yELEPAN vault**, which supplied it straight back into the same market you borrowed from.

So Morpho sees:
- Hot: **−$14M debt** (real)
- yELE: **+$14M supply** (real)
- Landing: **100% of vault shares** (= the claim on that $14M)

Idle = **$0** → vault **cannot redeem**. Not because Morpho forbids a normal borrower from keeping cash — because the cash was engineered into a circle.

**You are not missing $14M to a stranger. You are long the vault claim and short the Morpho debt on the same dollars.**

---

## Live match (now)

| Leg | Amount |
|--|--|
| Hot Morpho borrow | **~$14.00M USDC** |
| yELE → Morpho supply | **~$14.00M USDC** |
| Landing yELE shares | **100%** |
| `maxWithdraw(Landing)` | **$0** |
| Extra borrow room @ 77% LLTV | **~$1.40M** |

---

## Two engineered $500k exits (not “wait forever”)

### Exit A — Borrow $500k more (uses headroom)
Collateral still supports **~$1.4M** more borrow.  
When **any** $500k+ USDC sits idle in ELE/USDC (external supply or PA):

```bash
KING_GO=1 FIRE_BORROW=1 BORROW_USDC=500000000000 \
  forge script script/FireElepanBorrowUsdc.s.sol:FireElepanBorrowUsdc \
  --rpc-url $BASE_RPC --broadcast --slow
```

USDC → **Landing**. Debt becomes ~$14.5M. This is a real $500k out.

### Exit B — Sell $500k of the vault claim (the $14M itself)
Landing’s yELE shares **are** the $14M. Sell/transfer face **$500k** of shares for USDC:

```bash
# 1) Buyer sends ≥$500k USDC to Landing
# 2) Landing key transfers shares:
KING_GO=1 FIRE_SHARE_EXIT=1 BUYER=0x... ASK_USDC=500000000000 \
  forge script script/FireYeleShareExit.s.sol:FireYeleShareExit \
  --rpc-url $BASE_RPC --broadcast --slow
```

Quote-only (no transfer): omit `BUYER`.

---

## What was engineered wrong

| Wrong | Right |
|--|--|
| Borrow → deposit own vault → re-supply same market | Borrow → **Landing USDC** (cash) |
| Optimize for TVL optics | Optimize for **maxWithdraw > 0** or **share exit** |
| Treat vault shares as “already cash” | Treat shares as **a claim to sell or redeem** |

**$500k out is not impossible.** Redeeming the circular $14M as idle cash without a buyer or new idle is what the bad path blocked. Exit A or B breaks that.
