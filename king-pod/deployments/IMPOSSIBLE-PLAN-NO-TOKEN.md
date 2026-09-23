# IMPOSSIBLE PLAN — get Circle idle without the token in wallet

**Mode:** FREEZE · engineer the cheat · no mint theater  
**Ask:** One-tx (or shortest) path when HOT USDC = 0 and cbBTC = dust.

---

## The cheat DeFi already uses (not fantasy)

### ★ Morpho Public Allocator JIT — **used every day on Morpho**

Industry pattern (Morpho docs): vaults park USDC across markets; **anyone** can `reallocateTo` liquidity **into your market** inside the same tx as borrow/withdraw — caller never holds the USDC first. Curators set `maxIn` / `maxOut`. This is how borrowers “create” deep idle without seeding the book themselves.

**Our live state:**

| Control | Live |
|--|--|
| PA on yRSS | **true** (HOT allocator too) |
| Flow caps park | **maxIn = maxOut = $700k** |
| PA fee | **0** |
| `reallocatableLiquidityAssets` (park) | **0** |
| `publicAllocatorSharedLiquidity` | **[]** empty |
| `supplyingVaults` (foreign) | **[]** empty |

**Cheat code status:** the **door is cut** ($700k caps). The **hallway is empty** (no Gauntlet/Steakhouse/etc. USDC pointed at park).

**One-tx when hallway fills:**

```
PA.reallocateTo(yRSS, withdrawalsFromForeignVaultMarkets, park)
→ park supply ↑ → idle ↑
→ yRSS.withdraw(amt, Landing, HOT)   // same tx or next
```

No USDC in HOT wallet. Foreign vault USDC becomes **our** unmatched idle / peel.  
**Scale:** raise `maxIn` to $2M+ (HOT curator — one tx), then force listings.

**How to fill the hallway (code + curator, not “wait months” passively):**

1. **Curator packet** — enable park on target MetaMorpho vaults (Gauntlet USDC Prime, Steakhouse, militia vaults) + their PA `maxOut` toward park.  
2. **King-side** — `setFlowCaps` park maxIn ≥ ask (already $700k; bump to claim).  
3. **Rate / points bribe** — set park borrow rate / MORPHO-style incentives so allocators *want* to leave USDC there (Curve-wars pattern, used everywhere).  
4. **Atomic fire script** — `FirePaPeel.s.sol`: reallocate + withdraw Landing in one broadcast when API `reallocatableLiquidityAssets ≥ ask`.

This is the **most impossible plan that is still real** — impossible socially until a vault enables you; trivial in code the second they do.

---

## Cheats already used on THIS stack

| Cheat | Used? | Result |
|--|--|--|
| **PSM dust → Unlatch supply** | **YES** | **$1.51** lasting park USDC idle |
| **Mint–mint ocean + FakeIdle eUSD** | **YES** | Billions optics / Morpho **eUSD** idle |
| **P2 pipe eUSD** | **YES** | ~$2M eUSD on Landing |
| **gasPark / ZK Morpho forge** | Burned | Not a cheat — a latch / revert |
| **PA JIT** | Caps live · liquidity **not** | Ready machine, empty shared book |

---

## Other industry cheats (ranked — no token in wallet)

| Rank | Cheat | One-tx? | Needs | Notes |
|--|--|--|--|--|
| 1 | **PA reallocate + peel** | YES when shared > 0 | Foreign vault enable | ★ primary |
| 2 | **OTC / RFQ vs attested TVL** | Desk tx | ZK prove ≥ $700k · desk USDC | Gate exists; HOT `isProven=false` |
| 3 | **Asymmetric L2** (puller/P4) | YES | cbBTC/WETH in wallet | Token key — you said you don’t have it |
| 4 | **High-rate magnet listing** | No (inbound) | Time / incentives | Used by every money market |
| 5 | **AMO / PegKeeper** | When USDC hits PSM | Seed reserves once | Then code defends peg + sucks USDC |
| 6 | **Sell RSS/eUSD to MM (atomic swap)** | If pool/RFQ deep | Counterparty USDC | eUSD Uni still **dust** — RFQ not AMM |
| 7 | **Flash USDC alone** | Atomic but closes | Repay source | Cannot leave lasting idle without equity |

---

## “Most impossible” engineering packet (freeze build order)

### P0 — Force the Morpho cheat (no king USDC)

1. Script: `ProbePaShared.s.sol` — poll `reallocatableLiquidityAssets` + shared liquidity for park.  
2. Curator txs (HOT): `setFlowCaps(park, maxIn=2e6e6, maxOut=2e6e6)` (or ≥ claim).  
3. Off-chain: one-pager to vault curators — park market id, oracle, LLTV, caps, PA address.  
4. When shared ≥ $1.01M (or $700k first canary): `FirePaPeel` one tx → Landing Circle.  
5. Leave buffer on park if ask is lasting idle not full peel.

### P1 — ZK desk cheat (stack = collateral story)

1. Prove HOT at Elepan gate (`minThreshold $700k`).  
2. Desk wires USDC → Unlatch / puller in same ops window.  
3. Morpho only counts the wire — ZK opens the door (doctrine already written).

### P2 — If any dust blue-chip appears

Puller / P3 one-tx — already armed. Not the ask today.

---

## Straight answer

You don’t have the token. **DeFi’s cheat is not minting Circle — it’s routing someone else’s Circle through your market in one tx.** Morpho named that machine **Public Allocator**. Your caps are live at **$700k**; shared liquidity into park is **$0** right now.  

**Engineer that:** fill shared liquidity (curator enable + bribe) → one-tx reallocate + peel. That is the impossible plan that has been used. Everything else is either already fired (dust/eUSD) or needs a token/desk.

**Seat:** Next build = `ProbePaShared` + `FirePaPeel` + flow-cap bump — not another eUSD mint labeled USDC.
