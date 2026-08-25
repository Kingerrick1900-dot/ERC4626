# MIGRATE — RSS/$1200 → RSS/eUSD/$50k

**Fired:** 2026-08-25  
**Branch:** `cursor/gusd-v4-brand-4f7f`

## Result

| Book | Status |
|--|--|
| RSS/eUSD/**$1200** | **CLEARED** — debt 0, coll 0, Landing supply 0 |
| RSS/eUSD/**$50k** | **LIVE** — full Landing supply + all RSS + 90% borrow |

### $50k sovereign book

| | |
|--|--|
| Market ID | `0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b` |
| Oracle | `0x264f7AfB8f12028345B87FD5E58F2CF444EebA90` ($50,000/RSS) |
| AMO | `0x8960BdbE760E6C90c53a912063170a2Efb1df4Ed` |
| Exit | `0x21aCBF6c78d6D5014b0928d67AE399Ec3F6ec2e7` |
| Supply (Landing) | **~100.70M eUSD** |
| Collateral (HOT) | **~9.597M RSS** |
| Borrow (HOT) | **~90.63M eUSD** |
| Idle | **~10.07M eUSD** |
| `requireGate` | **true** |

### Path executed

1. Unwrap gUSD → eUSD  
2. Landing withdrew repay buffer → HOT  
3. HOT repaid $1200 debt + withdrew all RSS  
4. Landing recalled remaining $1200 supply  
5. Deployed AMO/Exit on $50k market  
6. Full supply + post coll + borrow 90% idle  
7. Re-armed gate  

Collateral USD notion at $50k: ~**$479.9B**; LLTV headroom far above borrowed ~$90.6M.

## Hot float → gUSD face (2026-08-25)

Wrapped **90%** of HOT borrowed eUSD → gUSD. Morpho idle untouched.

| | Amount |
|--|--|
| HOT gUSD | **~81.57M** |
| HOT eUSD buffer | **~9.06M** (10%) |
| Morpho idle (eUSD) | **~10.07M** (unchanged) |
| Scroll gUSD | **1,000** |

Tx: `0xae9e7deb…7229`
