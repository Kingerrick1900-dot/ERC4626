# Morpho ELE Loan + ZK Pack — Prep (NO GO)

**Status:** PREP ONLY. No live deploy / broadcast until `LIVE_ARMED=1` + `KING_GO=1` + `FIRE_LOAN_PREP=1`.

**This is a Morpho loan.** ZK is **packing** (attest / gate), not the credit engine.

**Pre-loan scale customize:** see `MORPHO-SCALE-CUSTOMIZE.md` (yRSS curator allocation report + cbBTC/WETH target).

---

## Loan = Morpho Blue

```text
borrow(assets, 0, onBehalf=hot, receiver=Landing)
```

Any slice up to `room ∩ idle`. Same loan, same call.  
Wrappers: `borrowPortion` / `borrowPortionZk` → still Morpho `borrow()`.

| Leg | Spec |
|--|--|
| Market | ELE/USDC `0xa4ec5271…da53fc` · 77% LLTV |
| Coll | Elepan on hot (on-chain — Morpho must see it) |
| Access | Portion `borrow` → Landing KEEP |
| Exit | `CrownElepanPreSelfLiq` (Morpho flash self-liq) |
| Forbidden | Recycle KEEP USDC into yELE |

---

## Pack = ZK gate (not the loan)

| Piece | Role |
|--|--|
| Gate `0xca2a…f30` | Pack: `isProven` + attest ≥ threshold ($1M / $700k) |
| KeepDraw / PreSelfLiq | Require pack before Morpho actions |
| `CrownMorphoZkPack` | Hub: Morpho meters + pack check + optional ZK credit rail |
| Credit `0xc415…d936` | Separate counterparty USDC rail (still not Morpho idle) |

Live pack: proven **true** · attest **$1M** · Morpho idle ≈ **0**.

---

## Passive — diversified → Landing

| # | Rail |
|--|--|
| P1 | yRSS fee → Landing (live 10%) |
| P2 | yELE fee → Landing (arm at GO) |
| P3 | Blue supply APY when external borrowers use ELE market |
| P4 | PreSelfLiq skim |
| P5 | ZK credit match (pack rail; pool $0 until supplier) |
| P6 | Optional thin Uni eUSD/USDC LP fees |

KEEP on Landing stays liquid — never recycle.

---

## User-independent scale (before loan)

| Lever | Kingdom use |
|--|--|
| Curator allocate | yRSS → prefer cbBTC/WETH over BRETT when TVL real |
| Flash / Blue seed | Bootstrap ELE idle; KEEP still needs leftover idle or owned seed |
| Fees | Already → Landing on yRSS; yELE at GO |
| Merkl | Optional TVL bootstrap — not required for `borrow` |

---

## Prep (no broadcast)

```bash
cd king-pod
forge script script/FireYrssCuratorPrep.s.sol:FireYrssCuratorPrep --rpc-url $BASE_RPC
forge script script/FireElepanLoanPrep.s.sol:FireElepanLoanPrep --rpc-url $BASE_RPC
forge test --match-contract ElepanLoanPrepFork -vv
```
