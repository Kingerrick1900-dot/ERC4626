# Goal: $500k–$700k real USDC seed (use the Morpho loan as leverage)

## Live loan leverage (Base / hot `0x6708…a7d1`)

| Book | Collateral | Borrow | Supply | Idle | Headroom |
|--|--|--|--|--|--|
| ELE/USDC **77%** | ~86.0M ELE | ~$50.01M | ~$50.01M (king≈100%) | **$0** | LTV headroom only — no idle |
| ELE/USDC **$10 / 91.5%** | ~14.0M ELE | **$700k** | **$700k** | **$0** | ~$127M notionally @ $10 — no idle |
| Morpho PA into either market | — | — | — | **reallocatable = 0** | `publicAllocatorSharedLiquidity: []` |

Matched Morpho flash loops do **not** mint a $700k wallet seed. The loan **does** size a credit/MM deal.

---

## Play 1 — Refinance the $700k TEN loan with desk USDC (primary)

**Use the existing $700k Morpho borrow as the bridge.**

1. Desk / MM wires **$700k USDC** to hot (loan or working-capital facility).  
2. On-chain atomic (king):  
   - `repay` $700k on TEN market `0x96228d1e…d7cc`  
   - `withdraw` $700k king USDC **supply** (idle appears the moment debt is repaid)  
   - optional: `withdrawCollateral` some/all ~14M ELE for MM inventory  
3. Result:  
   - **~$700k USDC** in kingdom control (seed)  
   - Morpho TEN borrow closed  
   - Obligation sits with the **desk** (their loan terms), not a fake idle mint  

This is the Morpho loan used as leverage: you refinance it so the matched supply becomes withdrawable cash.

**On-chain prep we can fire the day wire hits:** `FireTenRefinanceSeed` (repay→withdraw supply→optional coll out).

---

## Play 2 — MM loan/call on ELE inventory (Wintermute / DWF / Keyrock style)

**Loan ELE; desk posts the USDC seed.**

| Term | Ask |
|--|--|
| ELE loan | 2M–14M ELE (from TEN unlock or free) |
| USDC seed | **$500k–$700k** into hot or UniV3 ELE/USDC `0x4615a3E4…7410` |
| Model | Loan + call option **or** retainer + working capital |
| Proof | Morpho engine ~86M ELE coll + $50M credit book + TEN $700k facility |

Desk balance sheet = the $700k. Kingdom keeps ops/pool seed. Not a public ELE sale.

---

## Play 3 — Hybrid (fastest to “seed in pool”)

1. Play 1 wire $700k → refinance TEN → USDC on hot.  
2. Split: **$500k–$600k** seed UniV3 / Morpho idle you control; **$100k–$200k** ops float.  
3. Optional: loan remaining free ELE to MM (Play 2) to deepen books without spending seed.

---

## Packet to send a desk (copy)

```
Kingdom Base — USDC seed facility $500k–$700k
Borrower/hot: 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
ELE: 0x50639C42E2FFDEC4F68FB468968a55b3Af944583 (8dp)
Morpho Blue: 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb

Existing leverage:
- ELE/USDC 77% market 0xa4ec5271…da53fc — ~86M ELE coll, ~$50M debt
- ELE/USDC $10/91.5% market 0x96228d1e…d7cc — ~14M ELE coll, $700k debt + $700k supply (refinance target)

Ask:
A) $700k USDC loan to refinance TEN (repay Morpho → withdraw supply → seed stays with kingdom), or
B) MM loan: ELE inventory in / $500k–$700k USDC working capital out for pool+ops

Settlement: USDC 0x833589…2913 on Base to hot. Atomic refinance script ready on wire.
```

---

## Fire when wire lands

```bash
KING_GO=1 FIRE_TEN_REFANCE=1 \
forge script script/FireTenRefinanceSeed.s.sol:FireTenRefinanceSeed \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

(Script ships next — repay TEN debt with balance USDC, withdraw supply to hot, optional ELE out.)
