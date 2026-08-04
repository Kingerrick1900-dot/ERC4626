# PROTOCOL OPS BOOTSTRAP — the common DeFi survival problem

**This is not a King-only curse.** Most protocols die the same way: product ships, books look real on paper, **no redeemable runway to pay ops**. Recycled “advice” then says only teams with millions of USDC backing can play. That feedback loop **is** how DeFi stays an elite game.

**Wrong framing (rejected):** “change doctrine or stay broke” / “build a desk and hope a whale fills it.”

**Right framing:** engineer a **protocol credit → ops** path the same way survivors do — then grow convert + revenue. Maker did not wait for a USDC endowment to pay builders; it **generated Dai against collateral** and built the economy around that credit.

---

## 1. The common failure mode

| Failure | What it looks like |
|--|--|
| USDC-only victory before convert exists | Starvation while treasury “value” sits in unusable form |
| Empty-bowl machines | Completer / escrow / RFQ as the *plan* instead of a side door |
| Circular self-lend as payroll | Flash → vault → same-market borrow → shares, not bills |
| AI recycled walls | Treat conservation of *USDC* as proof the protocol cannot pay ops at all |
| Elite gate | “Bring external USDC first” as the only allowed first move |

Survivors reverse the order: **ops credit in the protocol unit first**, convert surface second, external stables as amplification — not as permission to exist.

---

## 2. What this kingdom already has (usable now)

| Piece | Live | Bootstrap role |
|--|--|--|
| Landing eUSD | **~$900k already on Landing** | **Ops float in protocol unit — already drawn** |
| eUSD mint (hot owner/minter) | Live | Ongoing protocol credit |
| Bound gate | Proven **$700k** · LLTV 70% · maxAsk **$490k** | Cap / discipline on credit draws |
| Free RSS ~8.83M + oracle markets | Live | Collateral for formal CDP (RSS→eUSD) |
| yRSS 10% fee + rate magnet | Live | Revenue **when external USDC supplies** (not self-loop) |
| `CrownBaseUsdcPsm` | Code live · reserve $0 | Convert rail when first USDC atoms earned/granted |
| `CrownOpsEusdDraw` | **New — this PR** | Bound-capped eUSD mint → Landing (Maker-shaped ops loan) |

**Hard truth without elite framing:** Landing already holds ~900k eUSD. Defining “nothing done” as “no USDC” while ignoring protocol-unit float **is** the game-brain failure mode.

---

## 3. The right solution — three engines (no desk-hope as strategy)

### Engine A — Protocol ops credit (eUSD) ← PRIMARY SURVIVAL

Pay ops, contributors, infra, and counterparties who will take **eUSD**.

1. Use Landing eUSD **now** where accepted.
2. Deploy `CrownOpsEusdDraw` — Bound-capped mint to Landing (loan-shaped, not infinite clown print).
3. Optional next: Morpho **RSS/eUSD** market (King sole supply via mint) = formal Maker vault: post RSS → borrow eUSD → ops.

```bash
# deploy + wire minter (no draw)
FIRE_OPS_EUSD=1 forge script script/FireOpsEusdDraw.s.sol:FireOpsEusdDraw \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# draw example 100k eUSD to Landing (King GO)
DRAW_EUSD=100000000000000000000000 FIRE_OPS_EUSD=1 \
  OPS_DRAWER=0x… forge script script/FireOpsEusdDraw.s.sol:FireOpsEusdDraw \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

This is **leveraging loan access into paying ops** in the unit the system can actually issue.

### Engine B — Convert surface (earn USDC atoms; don’t presuppose millions)

USDC becomes an **earned / granted / fee** asset, then PSM + markets amplify:

| Source | Why it is not “elite only” |
|--|--|
| Base Builder Grants (~1–5 ETH retro) | Shipped code → ETH → seed PSM |
| Flash-router / PSM fees | Users pay the protocol |
| Curator performance fees on **external** yRSS supply | Rate magnet at high util — real borrower demand |
| Bilateral eUSD↔USDC with anyone who wants eUSD exposure | Consenting swap, not silent vault drain |
| Named Completer/Tenor | Side door — **not** the spine |

First USDC into `CrownBaseUsdcPsm` unlocks eUSD→USDC redeem for the fraction of bills that truly need USDC.

### Engine C — Collateralized USDC borrow on **own** market (amplify later)

Empty $1200 RSS/USDC market stays ready. When Engine B produces USDC, King seeds **that** market → borrow vs RSS → Landing. Own liquidity, own collateral. Still no silent foreign PA.

---

## 4. What we refuse (still)

- NAV / `supply(onBehalf)` donation games  
- Pretending foreign Morpho idle is “our loan”  
- Desk-hope as the grand plan  
- Dumping RSS/Elepan to fake runway  
- Telling builders they must be millionaires to ship  

---

## 5. Scoreboard that matters

| Metric | Meaning |
|--|--|
| Landing eUSD spent on real ops | Protocol credit working |
| `CrownOpsEusdDraw.drawnEusd` vs Bound cap | Disciplined loan, not clown mint |
| PSM USDC reserve ↑ | Convert coming online |
| External USDC in yRSS / $1200 market ↑ | Revenue + borrow depth without self-loop |
| Landing USDC ↑ from fees/grants/borrows | Amplification — not permission to exist |

---

## 6. Immediate sequence (engineering, not vibes)

1. **Treat Landing ~900k eUSD as ops seed** — route real costs through it.  
2. **King GO:** deploy `CrownOpsEusdDraw` + setMinter (draw only if more eUSD credit needed under Bound).  
3. **Parallel:** Base grant / fee rails / PSM seed from first earned USDC.  
4. **Later:** RSS/eUSD Morpho CDP + own-seed $1200 USDC borrow when atoms exist.

---

## 7. One-block copy

```text
COMMON PROBLEM: protocols die with no ops runway
RIGHT PATH: protocol credit (eUSD) pays ops → earn/grant USDC → PSM/borrow amplify
NOT: desk-hope / elite USDC bankroll / NAV / foreign idle
Landing already ~900k eUSD — use it
CrownOpsEusdDraw = Bound-capped eUSD loan to Landing
```
