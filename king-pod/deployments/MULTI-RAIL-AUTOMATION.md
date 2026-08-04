# MULTI-RAIL AUTOMATION — King standpoint

**Law:** This is **not** a 2-option menu. Every path below is code, contracts, or bots.  
**Target:** spendable USDC on Landing `0x5Adc…2357`. Elepan never touched.  
**Scanner:** `python3 king-pod/script/ScanAllRails.py`

---

## Live board (inputs the King already holds)

| Asset | State |
|--|--|
| Free RSS (hot) | ~13.83M |
| Posted RSS / Morpho debt | 1.2M / ~$700k (~58% LTV) |
| yRSS V1 war chest | ~$700k TVL · `maxWithdraw≈0` |
| Vault V2 | live · ~$1 · `forceDeallocate` armed |
| Bound ZK gate | `isProven(hot)=true` @ $700k |
| Bound credit pool | **$0** USDC / `maxBorrow=0` |
| CrownSpoilFire | live `0xcFF60…45Fa` |
| Bundler3 | `0x6BFd…20C4` (unused this phase) |
| Aerodrome RSS/USDC | pool live · **~$1 USDC** depth (dust) |
| Tenor RFQs | $500k Armitage + broadcast — **active** |

---

## Rail map (automation / contracts)

| ID | Rail | Machine | Armed? | Opens when | Landing USDC |
|--|--|--|--|--|--|
| **R1** | Tenor Fixed RFQ | `FireTenorRssRfq500k.py` + accept tx | **LIVE inquiries** | Desk prices onchain offer | Yes → route Landing |
| **R2** | Morpho idle borrow (Option C) | `FireRssOptionCAtomicSeed.s.sol` `ADD_BORROW=1` | Armed | RSS market idle ≥ ask | Yes direct Landing |
| **R3** | Foreign PA maxIn → SpoilFire | `watch_maxin_fire.py` + `CrownSpoilFire` | Bot armed · maxIn=0 | Gauntlet/Steakhouse set `maxIn>0` | Yes → KingVault/Landing |
| **R4** | Own yRSS PA reallocate | yRSS `maxIn/maxOut=$700k` already | Caps live | yRSS has **spare idle** in other markets | Yes if cash exists (today none) |
| **R5** | Bound credit completer / autodraw | `CrownBoundLandingCompleter` / `CrownZkAutoDraw` | Proven · pool empty | Matcher/`credit.supply` USDC | Yes up to ~$490k (70%×700k) |
| **R6** | Vault V2 forceDeallocate | V2 + Morpho flash supply | Live · TVL~$1 | Real USDC deposited in V2 | Exit access only (not source) |
| **R7** | Wet Morpho (WETH/cbBTC) | Morpho borrow vs wet markets | Markets have huge idle | Hot holds sized WETH/cbBTC | Yes scales with wet |
| **R8** | Morpho Bundler3 atomic pack | `FireBundler3AtomicPack` + GA1 | **PRIMARY EXECUTOR** | R2/R3/R4 green → one-tx Landing | Yes when sub-rail opens |
| **R9** | CrownFlashRouter fee income | Flash desk fee skim | Live on other branch | External flash borrowers | Fee drip, not $500k |
| **R10** | Aerodrome RSS/USDC AMM | Pool `0x2C4F…537a` | Pool exists | Depth >> dust (**today $1**) | Spot only — doctrine: loan≠sell; King GO required |
| **R11** | yRSS share secondary / OTC vault | Sell/transfer yRSS shares | Packet only | Buyer of yield claim | Yes without selling RSS/Elepan |
| **R12** | Rate-magnet LP attractor | 100% util → max IRM | Passive | Outside USDC suppliers | Unlocks R2/R4 |
| **R13** | ERC-7683 / PSM solver rail | Scroll settler + Base PSM | Other branches | eUSD depth + solvers | Solver-fronted USDC |
| **R14** | Merkl / incentive magnet | Bribe deposits into yRSS/yELE | Scripts on branch | Campaign + whitelist | Indirect → R4/R5 |

---

## Four live avenues (King primary — not escrow)

See `FOUR-LIVE-AVENUES.md`. Real cash:

1. **Bound Completer / Permit2** (R5)  
2. **Tenor Fixed RFQ** (R1)  
3. **eUSD inventory unlock** (R13 / PSM depth)  
4. **Morpho idle + Foreign PA + Bundler3** (R2 / R3 / R8)

## What is NOT a rail

- Empty RSS escrow waiting to be filled (theater — optional side door only)
- Waiting for vibes / “the app likes us”
- Self-loop flash → yRSS deposit → same-market borrow as **payroll** (war chest only)
- Touching Elepan

---

## Parallel run order (Chief default)

All scanners run together — first green rail fires (King GO for broadcast):

```bash
# One shot — all rails
python3 king-pod/script/ScanAllRails.py

# Auto-fire first Bundler3-capable green rail (R2/R3/R4)
python3 king-pod/script/ScanAllRails.py --auto-fire --ask 500000

# Continuous hunt + auto-fire
python3 king-pod/script/ScanAllRails.py --poll --interval 60 --auto-fire
```

| Priority | If green | Fire |
|--|--|--|
| 1 | Morpho RSS idle ≥ ask (R2) | **Bundler3 pack** → Landing |
| 2 | Foreign PA `maxIn>0` (R3) | **Bundler3 + PA realloc** → Landing |
| 3 | yRSS spare withdrawable (R4) | **Bundler3 + yRSS PA** → Landing |
| 4 | Tenor offer ≥ $500k (R1) | Accept on Tenor → Landing |
| 5 | Credit USDC > 0 + proven (R5) | Completer / AutoDraw → Landing |

---

## Physics (honest, not narrow)

Every rail that lands **spendable** USDC either:

1. pulls **outside** USDC (desk, PA vault, credit LP, wet coll markets, solver), or  
2. exits a claim someone else will buy (yRSS shares / later V2).

Automation is how we **catch** that USDC the second it appears — not how we invent it from a closed loop. The kingdom already built most of these machines. We run them all. We do not sit on two chairs.
