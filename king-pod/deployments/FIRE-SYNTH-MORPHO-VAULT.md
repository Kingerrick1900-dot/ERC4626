# FIRE — Synth Morpho Vault (Falcon path · permissionless)

**Mode:** FIRE · executed on Base  
**Doctrine:** No buyer. List the synth. Let borrowers pull real USDC.  
**Precedent:** Ethena USDe on Morpho · Falcon sUSDf collateral → borrow USDC · Steakhouse HY vaults (high-risk label).

---

## LIVE

| Item | Value |
|--|--|
| **Morpho Blue market** | `0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd` |
| Loan | USDC `0x833589fC…2913` |
| **Collateral (synth)** | **eUSD** `0xE8aAD0DD…Caf8a` |
| Oracle | Fixed $1 `0x284EC3A9…7D2e` (1e24 · 18dp/6dp) |
| IRM | AdaptiveCurve `0x46415998…2687` |
| LLTV | **86%** |
| **MetaMorpho vault** | [`0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C`](https://basescan.org/address/0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C) |
| Name / symbol | `King Synth eUSD USDC Vault` / **`ySYNTH-USDC`** |
| Owner / Curator | HOT `0x6708…a7d1` |
| Allocators | HOT + Landing |
| Supply cap | **$200,000,000** USDC |
| Fee | 10% → HOT |
| Timelock | 0 |
| Dead seed | **$1** → `0xdead` |
| yRSS gold rail NAV | ≈ **$240.66M** (attest / 2035 ZK path) |

### Key txs

| Step | Tx |
|--|--|
| `createMarket` (eUSD coll / USDC loan) | [`0x6372b15d…66cb`](https://basescan.org/tx/0x6372b15d718c1811aabba3c4dfc4d4b200581423dc63af300e4f1ca8872066cb) |
| `createMetaMorpho` ySYNTH-USDC | [`0x53a95b68…4514`](https://basescan.org/tx/0x53a95b68a0074581816f184c13e3a006f6eceef401c192cc6bffea73dd534514) |
| `acceptCap` + `setSupplyQueue` | [`0x5efbc698…b2f4`](https://basescan.org/tx/0x5efbc698f53b67b9dc1470beeb87cb2463edd1db3fd14c8c2d8a535987fab2f4) · [`0x5711e974…f169`](https://basescan.org/tx/0x5711e9742da6e1e8deb1f32299a514d4aad7e58aac1d94501c3ecff8ce46f169) |
| $1 dead `deposit` | [`0x6c03d179…4df1`](https://basescan.org/tx/0x6c03d1796cb7877d747530e49dd002614597fb1c82bbd98e3227c7f5addc4df1) |

Script: `script/FireSynthMorphoVault.s.sol`

**Also live (prior):** Vault V2 `0xB96BcfFB…A7b9` on RSS/USDC market `0x40ac09f3…b794` — see `VAULT-V2-LIVE.md`.

---

## How the market fills (Falcon loop)

```
Outside USDC → deposit ySYNTH-USDC
  → vault supplies Morpho eUSD/USDC market
Borrower posts eUSD (ZK-proven Kingdom synth) as collateral
  → borrows USDC
  → real Circle USDC leaves the vault to the borrower
```

No Kingdom “buyer.” Borrowing demand is the exit. Gold rail / 2035 ZK attest is the risk story for the synth.

---

## Risk disclosure (required)

| Label | Fact |
|--|--|
| **Risk class** | **HIGH** — synthetic collateral (not blue-chip USDC/ETH-only) |
| Strength | eUSD mint gated by capacity + Dilithium/PQ + borders; 2035 Stark/settlement proofs live; yRSS gold NAV ~$240M |
| Weakness | Oracle is Kingdom fixed $1 — not a market TWAP. If eUSD depegs vs that print, liquidations / bad debt follow Morpho rules |
| Not claimed | Morpho app listing · Gauntlet/Steakhouse endorsement · insurance |

Vaults that accept synth collaterals on Base (Ethena/Steakhouse HY) carry the same high-risk label. Empty vault = market not yet convinced. Filled vault = demand found the rail.

---

## Scoreboard

```
FIRE=synth-morpho-vault ✓
MARKET=0x08039ffa…3fcd eUSD→USDC lltv=86%
VAULT=0xc91f3Bc5…c35C ySYNTH-USDC cap=$200M
SEED=$1 dead
GOLD=yRSS≈$240.66M
NEXT=borrowers post eUSD → pull USDC · optional Vault V2 adapter on same market
```
