# Sovereign Cold Mint $13M — LIVE

**Status:** SUCCESS · Access Clause enforced on-chain (`ColdMiss`)

## Cold wallet (confirmed)
`0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` (Landing)

## Live addresses
| Piece | Address |
|--|--|
| **Elepan CDP (Access Clause)** | `0xcdA6Ee292B4A7a02CF2C7Ff5d8Bfa971ac5c3A27` |
| eUSD (multi-minter) | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| treasury / feeRecipient | Landing (cold) |
| ZK gate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| Oracle | soft $1 `0xe290B586…cf19` |

## Position
| Field | Value |
|--|--|
| Collateral | **20.2M** Elepan |
| Debt | **13,000,000** eUSD |
| HF | **~1.5538** (≥ 1.55 floor) |
| Landing eUSD | **13,000,000** |
| Hot eUSD | **0** |
| Vault eUSD | **0** |

## Txs
| Step | Hash |
|--|--|
| Deploy CDP | `0x43e624e8…0ea102` |
| setMinter | `0x72cc85f5…f6774e` |
| approve | `0x7fb92ae7…b7bb46` |
| deposit 20.2M | `0x968abbe1…cbe6a4` |
| mintTo(Landing, 13M) | `0x0a6a4ee6…a2d11f` |

## Safety rule (code)
`mint` / `mintTo` credit **only** immutable `treasury`. Wrong recipient or failed cold credit → `ColdMiss` → **full revert, debt does not open**.

## Superseded for this mint
Prior Elepan CDP `0xD010…` (no treasury / mint-to-hot) — left in place; **do not use for sovereign mint**.
