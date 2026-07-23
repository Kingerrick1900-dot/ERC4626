# Native Token Vault (Elepan CDP) — LIVE on Base

**Status:** DEPLOYED + partial-withdraw smoke PASS.

## Canonical addresses (v2 — use these)
| Piece | Address |
|--|--|
| **eUSD** | `0xaeDcB6cCEc9739A3a2e4c4d3F914BC676a906E55` |
| **CDP vault** | `0xD0108e7570dB003D8140949d2b68Dd3e3F81ED14` |
| Collateral | Elepan `0x50639C42…4583` |
| Oracle | Soft $1 `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` |
| Owner / feeRecipient | hot `0x6708…a7d1` |

## Published params
| Param | Value |
|--|--|
| Liquidation ratio | **150%** |
| Safety floor | **155%** |
| Stability fee | **5%/yr** (minted to feeRecipient on accrue) |

## Deploy txs
| Step | Hash |
|--|--|
| eUSD create | (see `broadcast/FireElepanCdpVault.s.sol/8453/run-latest.json`) |
| CDP create | same broadcast |
| setMinter | same broadcast |

## Live verification — partial withdraw
Deposit 10 Elepan → mint 5 eUSD → withdraw 1 Elepan (HF 1.8 ≥ 1.55) → close (fee path).

| Step | Result |
|--|--|
| Partial withdraw | **PASS** (`SmokeElepanCdpContinue`) |
| Full close after fee dust | **PASS** (fee eUSD minted on accrue) |

## v1 note (superseded)
First deploy `eUSD 0x3a8C…F47A` / `CDP 0xB333…34f3` lacked fee mint-on-accrue; close could soft-stick. Recovered ~all Elepan; dust coll/debt left on v1. **Do not use v1.**

## CRITICAL — no full lock
Partial `withdraw` anytime if post-HF ≥ safety floor. Full unlock when debt = 0.

## Tests
`forge test --match-contract CrownElepanCdpVaultTest` — 9/9 PASS.
