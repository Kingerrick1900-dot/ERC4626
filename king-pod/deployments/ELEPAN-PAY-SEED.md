# $14M SPLIT PLAN — LIVE FACTS + PLAIN TEXT (NO DEPLOY)

**Status: NO DEPLOY.** King GO required before any broadcast.

---

## LIVE FACTS (checked now)

### Collateral / King bag
- Elepan (8dp) on hot: **~99,918,184**
- Soft-$1 oracle: **1e34** (live)
- For **$14M** borrow @ HF ≥1.55: need ~**21.7M** Elepan coll — **bag covers it**
- Soft LTV 70% need: ~**20.0M** Elepan

### Elepan/USDC Morpho moat
- Market id: `0xa4ec5271…da53fc`
- Loan USDC / coll Elepan / LLTV **77%** / AdaptiveCurve IRM
- Supply / borrow / idle today: **$0 / $0 / $0** (empty — must create idle before borrow)

### yELEPAN-USDC (Kingdom vault)
- Address: `0x61bfD6F7…145E`
- TVL: **$0** · supply cap: **$14M** · enabled
- Fee: **10%** → Landing `0x5Adc…2357`
- Timelock: **2 days**
- Allocators: hot + PublicAllocator **true**
- PA flow: maxIn=maxOut=**$700k** (raise on GO if JIT >$700k needed)

### Earn sinks (no depositor lockup; liquid ERC4626)
| Vault | Address | AUM | Live net APY | Vault fee | Curator timelock* |
|--|--|--|--|--|--|
| Gauntlet USDC Prime | `0xeE8F…b61` | ~**$427M** | **~4.47%** | 0% | 7d (params, not withdraw) |
| Steakhouse Prime USDC | `0xBEEF…b2` | ~**$229M** | **~4.24%** | 5% | 7d (params, not withdraw) |

\*Timelock = curator risk-param delay. Depositors redeem when vault has liquidity (standard MetaMorpho). Hot `maxWithdraw` = 0 today only because hot holds **zero shares** yet.

### Earn-leg math on **$7M** (live nets)
- Gauntlet ~4.47% → ~**$313k/yr**
- Steakhouse ~4.24% → ~**$297k/yr**
- Prefer **best net APY at fire**; re-quote that minute

### Flash / ops (no treasury USDC path)
- Morpho USDC inventory (flashable): ~**$177M**
- Hot ETH: ~**0.007** (top up before fire — gas)
- Hot USDC: dust (~$0.06)

### Ideal gates before fire
1. Idle path for **$14M** borrow (flash bootstrap and/or vault depth) proven on fork  
2. Post-borrow HF ≥ **1.55**  
3. Earn-leg: if comparing to our borrow APR, spread gate ≥ **150bps** or accept spend+earn split as ops funding (King call)  
4. Self-del dry-run: redeem sink → repay → free Elepan  
5. Hot gas funded  

---

## PLAIN TEXT PLAN (engineers)

**Name:** Split-Deploy Intent — $14M borrow, two destinations.  
**Do not deploy until KING_GO=1.**

### What we do
King posts Elepan. We borrow **$14,000,000 USDC** from the Elepan/USDC Morpho market (after idle exists). That borrow splits:

1. **Spend half (~$7,000,000)** → Landing / KingVault / treasury ops (Kingdom operating capital).  
2. **Earn half (~$7,000,000)** → deposit into Gauntlet USDC Prime or Steakhouse Prime USDC (pick higher **net** APY at execution). Shares to Landing. Accounting tracks both legs separately from day one.

Ratio default **50/50**. Adjustable by King before GO.

### Why split
- All $14M to Kingdom = zero Morpho earn.  
- All $14M to sink = zero ops funding.  
- Split does both jobs.

### Bootstrap (logistics — empty market today)
Market idle is $0. Engineers open with Morpho-permitted flash (King’s Elepan + gas, no treasury USDC wire):

- Flash USDC → seed depth into yELEPAN as needed so idle ≥ borrow ask  
- supplyCollateral(Elepan)  
- borrow $14M  
- route $7M Landing (spend) + $7M sink.deposit (earn)  
- repay flash from named REPAY_SOURCE (same-tx Morpho borrow / held flash remainder per final seeder design)  

Exact flash sizing is an engineer nail-down; intent destinations stay Spend + Earn.

### Atomic vs follow-up
**Prefer one atomic Intent** (Split-Deploy): borrow → two transfers (Landing + sink) in one tx so Accounting never sees a “loose $14M” state.  
Fallback: borrow → Intent A spend → Intent B earn (worse; only if atomic fails fork).

### Risk / exit
- Soft LTV ≤70%, HF ≥1.55, Risk Controller before fire.  
- Anytime self-del: redeem earn shares → repay Morpho → withdraw Elepan; spend half already at Landing.  
- Daily check: HF, sink APY, Landing balances, PA/idle.  
- Months run; savvy upsize only on new GO.

### Engineer checklist (logistics)
- [ ] Confirm split ratio (default 50/50)  
- [ ] Quote Gauntlet vs Steakhouse **net** APY at fire; pick winner  
- [ ] Confirm sink redeem path (no depositor lockup) on fork  
- [ ] Flash + Split-Deploy seeder + Intent logging (spend leg vs earn leg)  
- [ ] forceDeallocate / flash exit paired  
- [ ] Fork PASS → wait for **KING_GO=1** → fire  

### King decisions still open
1. Split ratio (keep 50/50?)  
2. Sink preference (best-at-fire vs force Gauntlet/Steakhouse)  
3. Spend receiver (Landing vs specific KingVault addr)  
4. **GO** when ready  

**No deploy in this document.**
