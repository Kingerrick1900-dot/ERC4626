# Native Token Vault (Elepan CDP) — LIVE on Base

**Status:** DEPLOYED + ZK-gated + partial-withdraw smoke PASS.

## Canonical addresses (ZK CDP — use these)
| Piece | Address |
|--|--|
| **eUSD** | `0x2b87771181d5d59B8e0C4fEEc055bbBE0C447B99` |
| **CDP vault** | `0x3b07C86a4058B160C84aF860100bE5FfDD0685eB` |
| **ZK gate** | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` (CrownZkElepanGate) |
| Collateral | Elepan `0x50639C42…4583` |
| Oracle | Soft $1 `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` |
| Owner / feeRecipient | hot `0x6708…a7d1` |

## Access
- **King-only** (`onlyOwner`)
- **ZK layer:** every mutation requires `zkGate.isProven(msg.sender)` (live Elepan wallet-bind, $700k threshold / 7d TTL)

## Published params
| Param | Value |
|--|--|
| Liquidation ratio | **150%** |
| Safety floor | **155%** |
| Stability fee | **5%/yr** (minted to feeRecipient on accrue) |

## Deploy txs
| Step | Hash |
|--|--|
| eUSD | `0xdc827fd16b4d173840aa959d4dd425b2d26f7dea86b9321b92082273e5088665` |
| CDP | `0xd614263a14ce629b3975e8efbb1ba60b07a71d3df9491ccd655806dc5be1ad97` |
| setMinter | `0x9b4325f5c4c3c19524d55cb5e938ee05722c62244cb899e34a89f15338f8129c` |
| partial withdraw (smoke) | `0x4112b27bd9862265465455d782dce28619ff5fc224c3e6c67bc0b708ef50ff54` |
| close (smoke) | `0xf25888f727ba4dba86193883140134d561eb2e75cbe142921e46c572296cd480` |

## Live verification
Deposit 10 Elepan → mint 5 eUSD → withdraw 1 Elepan (HF 1.8 ≥ 1.55) → close — **PASS** under ZK gate.

## Superseded
| Rev | eUSD | CDP | Note |
|--|--|--|--|
| v1 | `0x3a8C…F47A` | `0xB333…34f3` | no fee mint-on-accrue |
| v2 | `0xaeDc…6E55` | `0xD010…ED14` | fee mint OK, **no ZK** |
| **v3 (canonical)** | `0x2b87…7B99` | `0x3b07…85eB` | **ZK + fee mint** |

## CRITICAL — no full lock
Partial `withdraw` anytime if post-HF ≥ safety floor. Full unlock when debt = 0.

## Tests
`forge test --match-contract CrownElepanCdpVaultTest` — 10/10 PASS (incl. `test_requires_zk_proven`).
