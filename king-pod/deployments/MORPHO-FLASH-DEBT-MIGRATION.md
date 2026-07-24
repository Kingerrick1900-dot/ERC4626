# Morpho flash / debt-migration — what the docs actually say

Live check (Base ELE/USDC `0xa4ec5271…da53fc`):

| Meter | Morpho API / chain |
|--|--:|
| `liquidityAssets` | **3 wei** |
| `reallocatableLiquidityAssets` | **0** |
| `publicAllocatorSharedLiquidity` | **[]** (empty) |
| `supplyingVaults` | **[]** |

---

## 1) LI.FI “Debt Migration” (two flash loans)

**Source:** https://docs.li.fi/composer/composer-api/recipes/debt-migration  
**Not Morpho core docs.** LI.FI Composer recipe. Banner: *“Not public yet.”*

**Exact scenario in the recipe:**

- Source: **Aave V3** WETH-collateral / **USDC** debt  
- Dest: **Morpho Blue WETH/USDC** (deep USDC book)  
- Flash #1: USDC → repay **Aave USDC** debt  
- Flash #2: WETH → supply Morpho coll before Aave coll is freed  
- Morpho `borrow(USDC)` settles flash #1  
- Freed Aave WETH settles flash #2  

**Why this does not unlock Kingdom ELE → spendable USDC:**

| Recipe assumes | Kingdom live |
|--|--|
| Aave USDC debt | Sovereign **CDP eUSD** debt (different token) |
| WETH collateral on Aave | **Elepan** on CDP / Morpho |
| Dest Morpho market has USDC to borrow | ELE/USDC idle ≈ **$0** |
| Morpho borrow repays the USDC flash | `borrow` reverts: **insufficient liquidity** |

Debt migration moves an **existing USDC borrow** onto Morpho. It does **not** mint USDC into an empty isolated market. The Morpho borrow leg **requires idle (or PA-reallocatable) USDC** on the destination market.

---

## 2) Morpho SDK `refinance` (Blue → Blue)

**Source:** https://docs.morpho.org/tools/offchain/sdks/morpho-sdk/  
**GitHub:** morpho-org/sdks `MarketV1.refinance`

**What it does:**

- Migrate collateral + debt **Morpho Blue → Morpho Blue**  
- **Same `loanToken` + same `collateralToken`**  
- Flash-collateral via `onMorphoSupplyCollateral`: borrow target → repay source → withdraw source coll  
- Optional `targetReallocations` via **Public Allocator** when target idle is thin  
- Needs `setAuthorization(GeneralAdapter1, true)` once  

**Not applicable:** CDP eUSD → Morpho USDC (different loan token, not Blue→Blue).  
**Still needs:** target-market USDC liquidity (on-market or PA `maxIn` from a vault that already holds USDC).

---

## 3) Morpho `flashLoan` (core)

**Source:** https://docs.morpho.org/learn/concepts/flashloans/  
**Contract:** `morpho.flashLoan(token, assets, data)` → `onMorphoFlashLoan` → repay same tx (fee = 0).  
Flash can pull from Morpho’s **global** token balance (~$188M USDC on Base today).

**Use cases Morpho lists:** arb, collateral swap, self-liq, leverage, flash actions.

**Self-seed with flash (supply flash USDC into ELE market → borrow same size → repay flash):**

- Opens a circular supply+borrow book  
- **Net spendable USDC = ~0** (flash must be repaid same tx)  
- Same class of lock as the old yELE recycle — not Landing KEEP

Flash is a **bridge**, not a **liquidity printer**.

---

## 4) Morpho Public Allocator (documented path when idle is low)

**Source:** https://docs.morpho.org/developers/borrow/concepts/public-allocator/

When market idle < borrow size:

1. Query `publicAllocatorSharedLiquidity`  
2. `reallocateTo(vault, withdrawals, ELE_market)` within flow caps  
3. Bundle with `borrow` (Bundler3 / GeneralAdapter1)

**Kingdom ELE market today:** shared liquidity list is **empty**; external vault `maxIn` on this market is **0**.  
yELE has `$700k` flow caps but **$0 TVL** — nothing to reallocate.

This is the Morpho-native “no idle on *this* market yet” path — it still needs a **vault with USDC** and **curator `maxIn`**.

---

## Bottom line (docs → this book)

| Claim | Docs truth |
|--|--|
| “Flash migration gets USDC with no idle” | True only when the **destination Morpho market can lend USDC** (LI.FI example: WETH/USDC). |
| “Migrate CDP eUSD → Morpho USDC via two flashes” | Not a Morpho recipe. Wrong debt token + empty ELE book. |
| “25M ELE @ 77% ⇒ $19M USDC now” | LLTV **capacity**, not **available liquidity**. Capacity ≠ cash. |
| Real Morpho unlock for ELE/USDC | PA `maxIn` / Blue supply / matcher USDC → then `borrow` → Landing KEEP |

Armed Morpho coll on hot is the capacity side. The missing half is **USDC in the market** (permissionless supply or PA). Flash alone cannot fill that half into spendable Landing KEEP.
