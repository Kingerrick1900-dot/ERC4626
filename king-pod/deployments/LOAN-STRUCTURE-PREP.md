# Morpho ELE Loan + ZK Pack — Prep (NO GO)

**READ FIRST:** `KING-SETUP.md` — **not a yRSS loan.**

**Status:** PREP ONLY. No live deploy until `LIVE_ARMED=1` + `KING_GO=1` + `FIRE_LOAN_PREP=1`.

**Loan = Morpho Blue ELE/USDC.** ZK = pack only.

---

## Loan = Morpho Blue (the setup)

```text
borrow(assets, 0, onBehalf=hot, receiver=Landing)
```

Any slice up to `room ∩ idle`.  
`borrowPortion` / pack wrappers still call Morpho `borrow()`.

| Leg | Spec |
|--|--|
| Market | ELE/USDC `0xa4ec5271…da53fc` · 77% LLTV |
| Coll | Elepan on hot |
| Access | Portion → Landing KEEP |
| Exit | `CrownElepanPreSelfLiq` |
| Forbidden | Recycle KEEP into yELE/yRSS |

---

## Pack = ZK gate

Gate `0xca2a…f30` · proven / $1M attest. Does not create Morpho idle. Does not replace Morpho coll.

---

## Passive → Landing (diverse, around this Morpho book)

Skims/fees to Landing; KEEP stays liquid.  
**Not** “scale by curating yRSS.”

---

## Legacy (ignore for loan)

yRSS / yELE = dust / old vaults. See `MORPHO-SCALE-CUSTOMIZE.md` only as legacy inventory notes — **not** the operating loan.

---

## Prep (no broadcast)

```bash
forge script script/FireElepanLoanPrep.s.sol:FireElepanLoanPrep --rpc-url $BASE_RPC
forge test --match-contract ElepanLoanPrepFork -vv
```
