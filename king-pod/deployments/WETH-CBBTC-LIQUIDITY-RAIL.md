# Liquidity Bootstrap v1 — WETH / cbBTC production rail

**King GO architecture** · Base `8453` · 2026-07-28  
**Doctrine:** ELE = sovereign collateral. WETH / cbBTC = external liquidity assets. USDC = ops settlement.

```
ELE ──► Sovereign Collateral ──► Morpho ELE77 ──► Credit book (Bravo / Charlie)
WETH / cbBTC ──► Deep USDC markets + CDPs ──► USDC ──► Landing (Alpha)
```

---

## Separation of responsibilities

| Team | Asset | Job |
|--|--|--|
| **Alpha — Liquidity Rail** | WETH, cbBTC | Vault/CDP mgmt, mint/redeem policy, Uni routing, slippage, treasury accounting |
| **Bravo — ELE Treasury** | ELE | Morpho collateral, reserve health, capital efficiency — **not** public-market liquidity |
| **Charlie — Credit Ops** | ELE77 book | Headroom, rates, ratios, idle liquidity, repayment plan — borrow only if prudent |

---

## Live inventory (preflight 2026-07-28)

| Surface | Status |
|--|--|
| Hot ELE free | ~**74M** |
| ELE77 coll / borrow | **25M ELE** / **~$17.5M** matched |
| ELE77 idle | ~**$0** (3 wei supply surplus) |
| ELE77 soft headroom @ 77% | ~**$1.75M** (cannot draw — no idle) |
| Hot WETH / cbBTC | **0** / dust **1028** wei |
| Hot ETH | ~**0.00041** (~$1 — **not** ops inventory) |
| Base Landing USDC | **3 wei** |
| PSM USDC reserve | **0** (eUSD side ~145k; not convertible without USDC) |
| Foreign PA ELE77 maxIn | **0** (Gauntlet / Steakhouse) |
| yELE PA ELE77 maxIn/Out | **$700k** cap, but vault **totalAssets ≈ dust** — door closed |

### External market depth (usable)

| Market | Idle / depth |
|--|--|
| Morpho WETH/USDC | ~**$7.26M** idle |
| Morpho cbBTC/USDC | ~**$133M** idle |
| Uni WETH/USDC 0.05% | ~**$3.05M** USDC in pool |
| Uni WETH/USDC 0.30% | ~**$55.4M** USDC in pool |
| Uni cbBTC/USDC 0.05% | ~**$2.97M** USDC in pool |

**Verdict:** External USDC depth is real. Kingdom **inventory** of WETH/cbBTC and ELE77 **idle** are not. Charlie borrow → Landing is **blocked** until idle or PA maxIn opens. Alpha conversion is **blocked** until treasury holds WETH/cbBTC (or ETH) or PSM is USDC-funded.

---

## Canonical addresses

| Piece | Address |
|--|--|
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| ELE | `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` |
| WETH | `0x4200000000000000000000000000000000000006` |
| cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| eUSD (multi-minter) | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| WETH CDP | `0x60033c198bb686cEA1BAAF5a5CDc7b6e3Ddc9BCF` |
| cbBTC CDP | `0xb7Be10165c7A3296Cb621478B3dD497c65Da28d5` |
| PSM | `0x9199E5099C2C46A688F982E377a146Ab6db8060b` |
| Extractor | `0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58` |
| ELE77 | `0xa4ec5271…53fc` |
| WETH/USDC Morpho | `0x8793cf30…1bda` |
| cbBTC/USDC Morpho | `0x9103c3b4…1836` |
| Uni WETH/USDC 500 | `0xd0b53D9277642d899DF5C87A3966A349A798F224` |
| Uni cbBTC/USDC 500 | `0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef` |
| SwapRouter02 | `0x2626664c2603336E57B271c5C0b26F421741e481` |

---

## Alpha paths (priority order)

1. **Direct market** — treasury WETH/cbBTC → Uni (0.05% preferred) → USDC → Landing. ELE never sold.
2. **CDP mint** — WETH/cbBTC → kingdom CDP → eUSD → **PSM** → USDC (requires PSM USDC reserve).
3. **Morpho coll** — post WETH/cbBTC on Morpho 86% markets → borrow USDC → Landing (Charlie risk gates apply).

## Charlie gates (must all pass before borrow expand)

1. Redemption / conversion path healthy (PSM USDC > 0 **or** Uni depth ≥ ask × 1.2).
2. ELE77 idle ≥ ask **or** PA maxIn ≥ ask with reallocatable liquidity.
3. Post-borrow LTV ≤ soft policy (default 70% of LLTV 77% → ≤ **53.9%** soft; hard LLTV 77%).
4. Landing receive ask; repayment plan logged.
5. No ELE sale. No matched flash-seed as payroll.

## Scripts

```bash
# Read-only preflight (no broadcast)
KING_GO=1 forge script script/VerifyLiquidityRail.s.sol:VerifyLiquidityRail \
  --rpc-url "$BASE_RPC_URL"

# Fire Alpha direct swap when inventory + depth gates pass
KING_GO=1 FIRE_LIQ_RAIL=1 RAIL_MODE=SWAP ASSET=WETH \
  ASK_USDC=500000000000 MAX_SLIPPAGE_BPS=50 \
  forge script script/FireLiquidityRail.s.sol:FireLiquidityRail \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"

# Charlie borrowIdle when ELE77 idle ≥ ask
KING_GO=1 FIRE_LIQ_RAIL=1 RAIL_MODE=BORROW_IDLE ASK_USDC=500000000000 \
  forge script script/FireLiquidityRail.s.sol:FireLiquidityRail \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

---

## Chief Engineer checks (this turn)

| # | Check | Result |
|--|--|--|
| 1 | WETH/cbBTC Morpho borrow headroom (kingdom position) | **None** — 0 coll posted |
| 2 | USDC liquidity on conversion route | **PASS** — Uni + Morpho idle deep |
| 3 | E2E mint/convert/fees/slippage | Scripts + gate tests **PASS**; live fire **refuses** (`INVENTORY_LT_ASK`) |
| 4 | Treasury risk within policy | **HOLD** — `RAIL_FIRE_ALLOWED=0`; Charlie do-not-borrow |

**Live gate scoreboard:** DEPTH=1 · INVENTORY=0 · PSM=0 · IDLE=0 · HEADROOM=1 · PA_DOOR=0 · FIRE=0

**Bootstrap truth:** rails and depth exist; **funding inventory** (WETH/cbBTC sized to ask, or USDC idle into ELE77) is still the missing step. Standing architecture — no false Landing fill.
