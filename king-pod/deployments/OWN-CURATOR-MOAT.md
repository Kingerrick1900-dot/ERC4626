# Phase — Own Curator + Oracle Moat (no Bundler)

## 2) Become your own Curator — LIVE

Kingdom already is the curator. No Gauntlet whitelist required.

| Field | Value |
|--|--|
| Vault | **yRSS** `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Name | King RSS USDC Vault / `yRSS-USDC` |
| Owner / Curator / Allocator | King hot `0x6708…a7d1` |
| Asset | USDC |
| Fee | 10% → KingVault `0xA1aF…832a` |
| Timelock | 0 (raise later if needed) |
| Public Allocator | `0xA090…0467` (`isAllocator = true`) |
| RSS market | enabled, cap **$14M**, PA maxIn/maxOut **$700k** |
| TVL (live) | ~$546 (magnet empty until depositors arrive) |

### How the fat vault works
1. Depositors `deposit` USDC into yRSS for yield (100% util RSS book = rate magnet).
2. Kingdom (or PA) allocates USDC into owned Morpho Blue markets.
3. Borrowers (including Kingdom) borrow against collateral → real depth, fees to KingVault.

### Scripts
| Script | Purpose |
|--|--|
| `DepositYrss.s.sol` | `AMOUNT_USDC` → yRSS |
| `ArmYrssFatCurator.s.sol` | Caps + PA + queue for RSS + BRETT moat |
| `FirePositionSeed700k.s.sol` | PA pull → borrow → KingVault when idle exists |

```bash
AMOUNT_USDC=1000000 forge script script/DepositYrss.s.sol:DepositYrss --rpc-url $BASE_RPC_URL --broadcast
```

---

## 3) Oracle as competitive moat

### Moat A — RSS (already owned)
| Field | Value |
|--|--|
| Market | `0x40ac09f3…b794` |
| Collateral | RSS — no shared Chainlink herd |
| Oracle | Morpho FixedOracle `$1`, owner **burned to dEaD** |
| PoD | ~$9.25M @ ~100% util |

You own this niche. Depositors hunting that borrow demand come through **your** vault.

### Moat B — BRETT/USDC — LIVE (was zero Morpho markets)
| Field | Value |
|--|--|
| Market ID | `0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16` |
| Collateral | BRETT `0x532f27101965dd16442E59d40670FaF5eBB142E4` |
| Oracle | `MorphoUniV3Oracle` `0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619` |
| Price source | UniV3 TWAP 30m BRETT/USDC 1% `0xBF0A…6A4d` |
| LLTV | **62.5%** |
| Create oracle tx | `0x1bdfb4f9…fae5` |
| Create market tx | `0x694f9308…79a4` |
| yRSS BRETT cap | **$2M** USDC, PA maxIn **$700k**, queue slot appended |

```bash
python3 script/fat_curator_status.py
AMOUNT_USDC=1000000 forge script script/DepositYrss.s.sol:DepositYrss --rpc-url $BASE_RPC_URL --broadcast
```

Artifact: `deployments/brett-usdc-moat.json`
