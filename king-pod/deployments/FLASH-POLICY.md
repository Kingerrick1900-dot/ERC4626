# Flash policy — named repay source only

## Rule
A flash loan is allowed **only** when the atomic sequence names the exact on-chain source that closes repayment in the same transaction.  
**Forbidden:** flash to bridge a funding gap, hope for a later fill, or “temporary” liquidity with no step-N repay.

## Allowed pattern
```
1. flash(assets)
2. … productive steps …
N. repay from <NAMED_SOURCE>   # balance/callback/return path proven in callStatic
```

| Named source (examples) | OK? |
|--|--|
| Same-tx Morpho `borrow` against posted collateral with proven HF | YES |
| Same-tx vault `withdraw` / PA `reallocateTo` into market then borrow | YES |
| Same-tx DEX sell of inventory already held | YES |
| “We’ll get USDC later / curator tomorrow” | **NO** |
| Self-lend mirror with no external depth into KingVault | Mirror only — not ops funding |

## Kingdom rails under this policy
| Tool | Role | Repay source |
|--|--|--|
| `FirePositionSeed700k` | PA pull → borrow → KingVault | **Not a flash** — spot Morpho borrow |
| `CrownSpoilFire` | Armed fire when idle ≥ ask | Morpho borrow against live RSS collateral |
| Cross-/elite flash close scripts | Atomic close only | Must set `REPAY_SOURCE=` env + callStatic pass |

## Pre-flight (mandatory)
```bash
# Every flash path:
# 1) Document REPAY_SOURCE=<contract.method or market>
# 2) forge script … --sig 'run()' with callStatic / dry-run success
# 3) Broadcast only after static succeeds
```

Env contract for flash scripts:
```
FLASH_ALLOWED=1
REPAY_SOURCE=Morpho.borrow(RSS_MARKET)|Dex.swap(RSS→USDC)|Vault.withdraw(...)
```

If `REPAY_SOURCE` unset → script must revert before flash callback.
