# FREEZE AUDIT — “16z no-Boss USDC” pack

**Verdict:** Reject `CrownAeroToCircle_16z.sol`. Options 1–5 do not engineer ≥$1M Circle from HOT eUSD + 5B ocean as written. Option 6 is OTC (counterparty), not Solidity.

**Probed:** Base live · 2026-09-23

---

## Inventory (true)

| Asset | Live |
|--|--|
| HOT eUSD | **~$2.450M** |
| HOT gUSD | **~$2.03B** (unwrap → more eUSD; still kingdom) |
| HOT USDC / WETH / cbBTC | **0 / 0 / 1028 wei** |
| Landing USDC | **~$2.51** |
| Ocean Aero eUSD/gUSD `0x8C009d…eFE7` | **5B / 5B** · LP on Landing **~4.98B** |
| yRSS `totalAssets` | **~$1.086M** · HOT `maxWithdraw` = **0** |
| yRSS stuck in PARK | **~$1.080M** (≈100% of vault) |
| PARK util | **100%** · idle **$0** |
| PARK borrower | **HOT = 100%** of borrow shares (~$217M debt vs RSS coll) |
| Boss eUSD/USDC idle | **~$0.000002** (drained) |
| Boss reallocatable | **0** · supplying vaults **[]** |

---

## Option-by-option

### 1) Aero swap eUSD → WETH → USDC (or eUSD → cbBTC)

| Claim | Live |
|--|--|
| “You have 5B depth, swap $1.01M eUSD → WETH → USDC” | **False path** |

- Aero factory: **only** eUSD pair is stable **eUSD/gUSD** ocean. **No** eUSD/USDC, eUSD/WETH, eUSD/cbBTC (volatile or stable). **No** gUSD/USDC or gUSD/WETH.
- Aero CL factory: **no** eUSD pools found (tick spacings 1/10/50/100/200).
- Uni eUSD/USDC fee 500: USDC in pool **6312** (~$0.006). Fee 100: dust.
- Uni eUSD/WETH · eUSD/cbBTC: **no pools**.

Swapping into the ocean buys **gUSD**, not Circle. 5B mint–mint depth ≠ USDC exit.

**Kill:** first hop missing.

---

### 2) Other Morpho curators — Steakhouse / Gauntlet / Moonwell eUSD→borrow USDC

| Claim | Live |
|--|--|
| “6+ curators · supply $2.45M eUSD · borrow $1.01M USDC” | **False** |

Morpho GraphQL Base · `collateral=eUSD` · `loan=USDC`:

| Market | Liquidity | Vaults |
|--|--|--|
| Boss `0x5d46…366` (86% LLTV) | **~$0.000002** | **[]** |
| Alt `0x5acc…184` (77% LLTV) | **$0** (empty book) | **[]** |

No Steakhouse/Gauntlet/Moonwell eUSD-coll USDC books with fill. Coll capacity ≠ loan inventory. Same Boss law already audited.

**Kill:** loan side empty on every eUSD/USDC market.

---

### 3) eUSD → cbBTC (Aero/WETH) → Morpho cbBTC/USDC borrow $1.01M

| Piece | Live |
|--|--|
| eUSD → cbBTC / WETH hop | **Dead** (no Aero/Uni route — see §1) |
| Morpho cbBTC/USDC `0x9103…1836` idle | **~$161M** · 86% LLTV — **real if you hold cbBTC** |
| HOT cbBTC | **dust** |

Door C puller still correct: needs **~23+ cbBTC** funded, not minted from ocean.

**Kill:** cannot source cbBTC from eUSD on-chain today. Second hop alone is institutional; first hop is fantasy.

---

### 4) Flash $1.01M USDC → repay locker → peel deed → repay flash

| Claim | Live |
|--|--|
| “Repay the guy locking yRSS · peel $1.01M real · atomic” | **Misread of who locks** |

- Locker = **HOT** (sole PARK borrower), not an external party.
- yRSS assets ≈ PARK supply ≈ **$1.08M** at 100% util.
- Atomic `flash → repay PARK → yRSS.withdraw → repay flash` **can** unlock shares, but cash identity is:

```
−$F park debt  ·  −$F yRSS claim  ·  wallet USDC ≈ 0 − fee
```

That is **delever / burn the deed**, not mint Circle onto Landing. Prior dust peels already took the free util; remaining claim sits behind your own borrow.

Balancer Vault USDC spot **~$73k** — not enough alone for a $1.01M Balancer flash; size is secondary to the net-zero identity.

**Kill:** no net ≥$1M USDC; destroys ~$1.08M deed equity for ~$0 cash.

---

### 5) Unstake $1.01M ocean LP → swap to USDC → unmatch → peel → reseed

| Claim | Live |
|--|--|
| “Depth 5B → 4.999B invisible · seed Circle” | **False exit** |

`removeLiquidity` on `0x8C009d…` returns **eUSD + gUSD only**. Then same dead §1 hop to USDC. Optics dip is real; Circle is not.

**Kill:** LP ≠ USDC.

---

### 6) OTC sell HOT eUSD @ $0.80 → $800k USDC

| Claim | Live |
|--|--|
| Sell $1.01M eUSD for $800k USDC | **Possible off-chain only** |

Needs a **named MM / wire**. Not an Aero route. After USDC lands: `unmatchAndPeel` / park repay is then real. Do not code a “16z OTC” contract pretending AMM depth.

---

## Combined “Best A+C” pitch

**eUSD → cbBTC → Morpho → USDC → peel** — fails at **eUSD→cbBTC**. Writing `CrownAeroToCircle_16z.sol` would broadcast a revert or a gUSD loop.

---

## What still engineers USDC (unchanged doctrine)

| Path | Status |
|--|--|
| **Boss vacuum** | Armed `CrownBossWedge` — drain when idle refills |
| **Park util &lt; 100%** then peel | Needs **external** USDC wedge (OTC / lender / refill) to repay; flash alone nets ~0 |
| **cbBTC/WETH puller** | Armed — needs blue-chip coll on HOT |
| **Ocean 5B** | Live — magnet / optics only until a USDC door opens |
| **OTC / treasury wire** | Only ≥$1M Circle path that does not wait on Boss refill |

---

## One-block

```
REJECT CrownAeroToCircle_16z
Aero 5B = eUSD/gUSD only — no USDC/WETH/cbBTC hop
eUSD Morpho books = Boss dust + empty twin — not 6 curators
Flash peel = burn deed, net ~$0 Circle
cbBTC book deep — coll missing
OTC or Boss refill or fund cbBTC = only real doors
```
