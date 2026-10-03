# SEALED — $3M Bootstrap · Routes A + B (parallel)

**Decree:** Proceed $3M · A and B  
**Side:** King  
**Scoreboard:** HOT USDC hard balance only (`0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`)  
**Law:** ColdBuffer **30%** hard · FLASH-POLICY named repay · no mint into cbBTC Morpho book · no OTC/Circle beg

---

## Bootstrap allocation (exact)

| Bucket | USDC (6dp) | Share | Purpose |
|--|--:|--:|--|
| **Ocean seed** (DeepPull Uni eUSD/USDC) | `1_500_000_000000` | 50% | Phase-0 venue depth — Kingdom-owned LP |
| **Route B ask book** (gold→USDC target) | `1_500_000_000000` | 50% | Controlled conversion proceeds → HOT |
| **Route A** | `0` bootstrap capital | — | Fee plumbing only — compounds from day one |

**Total bootstrap notional:** `3_000_000_000000` USDC ($3,000,000).

Route A does **not** consume bootstrap dollars. Every fee stream splits **30% Cold / 70% HOT** forever.

---

## Live rails (Base)

| Piece | Address |
|--|--|
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| kXAU | `0x76822B470DeC1b94Df4219727288e7a196224853` |
| ColdBuffer | `0xBb3c14bBacD639797cB5c537fde370d1b7195521` |
| DeepPull (Ocean) | `0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A` |
| Uni eUSD/USDC fee500 | `0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666` |
| Uni SwapRouter02 | `0x2626664c2603336E57B271c5C0b26F421741e481` |
| Sovereign AMO | `0x151C947B813400fE78EE176843F2d666c07422eA` |
| AMO market (RSS/eUSD/$1200) | `0xc61adc…0599` |

---

## Route A — revenue engine (Maker/Aave pattern)

**Flow:** `feeSource → CrownRevenueSweep → 30% ColdBuffer.fund / 70% HOT`

| Param | Value |
|--|--|
| Contract | `src/CrownRevenueSweep.sol` |
| Cold split | `coldBps = 3000` (30%) — matches ColdBuffer law |
| HOT split | `7000` bps |
| Operator | HOT (or King-set) |
| Cadence | continuous — sweep on every non-zero fee accrual |
| Fee sources | King allowlist via `setFeeSource` (PayAdapter / Acquirer / LP fee sinks / desk) |
| Fire script | `script/FireRevenueSweep.s.sol` |

```bash
# Deploy (once)
HOT_KEY=$HOT_KEY forge script script/DeployRouteAB.s.sol:DeployRouteAB \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# Sweep one allowlisted source (amount 0 = full balance)
SWEEP=0x… SOURCE=0x… AMOUNT=0 \
  HOT_KEY=$HOT_KEY forge script script/FireRevenueSweep.s.sol:FireRevenueSweep \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

**Scoreboard effect:** HOT USDC ↑ by 70% of each sweep; ColdBuffer ↑ by 30%.

---

## Route B — gold rail → USDC (TWAMM / limit)

**Policy:** King Morpho gold borrow = **NONE**. Conversion is sale/fill only — not a royal leverage loop.

| Param | Value |
|--|--|
| Contract | `src/CrownGoldConvert.sol` |
| Sell tokens | kXAU (`0x7682…4853`) · yRSS (`0xF80C…D525`) |
| Target USDC out | `1_500_000_000000` ($1.5M) |
| Limit floor (kXAU) | **$9.80 / oz** = `9800000` USDC-6dp per 1 full kXAU (Kingdom $10 − 2% haircut) |
| TWAMM window | **7 days** (`604800` s) from `postTwamm` |
| TWAMM chunk | filler-driven; max single fill `150_000_000000` USDC ($150k) |
| Uni market sell | optional `uniSell` via SwapRouter02 when pool depth exists |
| Proceeds sink | **HOT only** |
| Fire script | `script/FireGoldConvert.s.sol` |

### kXAU ask sizing @ $9.80

| USDC target | kXAU full units (8dp) |
|--|--:|
| $1,500,000 | `15000000000000` / 9.8 ≈ **153,061.22448979** oz → post `15306200000000` (ceil) |

```bash
CONVERT=0x… \
  MODE=twamm TOKEN=0x76822B470DeC1b94Df4219727288e7a196224853 \
  AMOUNT_IN=15306200000000 MIN_USDC_PER=9800000 WINDOW=604800 \
  HOT_KEY=$HOT_KEY forge script script/FireGoldConvert.s.sol:FireGoldConvert \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

`MODE=ask` posts a single limit ask; `MODE=uni` market-sells via Uni with `MIN_OUT`.

---

## Ocean seed (50% of bootstrap — uses Route B proceeds + committed USDC)

| Param | Value |
|--|--|
| Venue | DeepPull Uni V3 eUSD/USDC fee 500 |
| USDC leg | up to `1_500_000_000000` |
| eUSD leg | co-mint matched 1:1 via DeepPull minter (yRSS inventory gate) |
| LP recipient | HOT |
| Flash deepPull | only if `REPAY_SOURCE=HOT USDC` prefunded (FLASH-POLICY) |

Do **not** fire Ocean seed until Route B has produced measurable HOT USDC **or** King wires external USDC for the USDC leg.

---

## Parallel sequence (exact)

```
T0  Deploy CrownRevenueSweep + CrownGoldConvert (DeployRouteAB)
T0  Allowlist fee sources on Sweep; set kXAU+yRSS sellable on Convert
T0  Arm ColdBuffer outflow only when sink = HOT or LSR (King flag)
T1  Route A: first sweepAll on each fee source (even if $0 — proves pipe)
T1  Route B: postTwamm $1.5M target ask book (kXAU @ $9.80 / 7d)
T2  Fills → HOT USDC scoreboard ↑
T2  Continuous Route A sweeps compound alongside
T3  When HOT USDC ≥ Ocean USDC leg: DeepPull.seed / sized deepPull
T4  Route C (incentives) only after proof readable + pool has depth — NOT this decree
```

---

## Kill rules

1. Scoreboard = HOT USDC balance. Nothing else.
2. ColdBuffer `minBufferBps = 3000` stays hard — never lower for “speed.”
3. No flash without `REPAY_SOURCE=` + callStatic pass.
4. No eUSD mint into cbBTC/USDC Morpho idle.
5. No King Morpho borrow against kXAU.
6. No $3M FIRE broadcast without capital path + King `FIRE_3M=1`.

```
BOOTSTRAP=3000000
ROUTE_A=CrownRevenueSweep coldBps=3000 → HOT
ROUTE_B=CrownGoldConvert targetUsdc=1500000 floor=9.80/oz window=7d
OCEAN=DeepPull seed≤1500000 when HOT USDC funds USDC leg
FIRE_GATE=FIRE_3M=1
```

---

## FIRE status

**FIRED on Base.** Live scoreboard + txs: [`FIRE-3M-AB.md`](./FIRE-3M-AB.md)

| | |
|--|--|
| Sweep | `0xd22cBd6f87DA859295b94c50e9dEB75842a18570` |
| Convert | `0x194f272CB9CFFD6B71C90A1cFdd5907a14E5923D` |
| TWAMM #0 | $1.5M kXAU ask @ $9.80 / 7d — open |
| HOT USDC | post-sweep scoreboard in FIRE doc |
