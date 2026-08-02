# Scroll Dominion — Elepan-native sovereign credit · LIVE

**Base stays intact.** Parallel domain. ELE inventory remains on Base hot.  
On Scroll, **Elepan is the ruleset**: attested credit capacity → completer → Landing.

## Doctrine

| Domain | Role |
|--|--|
| **Base** | Hold position (ELE). Morpho = optional venue under Morpho rules. |
| **Scroll** | Elepan-native credit engine. Sovereign attestation is first-class. |

## Live (Scroll · chainId `534352`) — fired

| Piece | Address |
|--|--|
| Hot / king | `0xca76AE9e29a5F01465D890dc30109cD58B78F864` |
| Landing | `0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f` |
| USDC | `0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4` |
| **Gate** | `0x777CCe01CbF472070b6c66dB2295b2d616171887` |
| **Credit** | `0x5c2511748a398AA7Fe144B44e0a433F5156A1368` |
| **Completer** | `0x2cf08F8150f7E89c7323615016b0c4D2811266f6` |
| **eUSD** | `0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B` |
| **Spoils dominion** | `0x8E5ff2552f8fE0730E89dA7fBF1721f910615DcD` |

## Parameters

| Param | Value |
|--|--|
| Attested capacity | **$1,000,000,000** (6dp) |
| minThreshold | **$700,000** |
| Credit LLTV | **70%** |
| **maxAsk** | **$700,000,000** |
| King proven | **true** |
| Base ELE after deploy | **unchanged** `9999979232502307` raw |

## Spoils path

`completer.complete(amount)` — matcher supplies Scroll USDC → credit → Landing.

## Sale-source Uni V3 (desk plumbing · LIVE)

Dust exit surfaces so kXAU / eUSD clear to USDC on Scroll. See `SCROLL-KXAU-EUSD-SALES-SOURCE-LIVE.md`.

| Pair | Pool | NFT |
|--|--|--|
| kXAU / USDC 0.3% | `0xce5Dd7bF3acd10152a601563AE2730b3E4dCD241` | `11056` |
| eUSD / USDC 0.3% | `0x5f3f22344FbBF23DD6cF63670B05d4C6689063Fc` | `11057` |
| kXAU / eUSD 0.3% | `0x9c5768f292A85080294C7764b54930F3C560788d` | `11058` |  
No Morpho. No Base write. Elepan honors attestation natively.

## Fire again / verify

```bash
KING_GO=1 FIRE_SCROLL_DOMINION=1 \
forge script script/FireScrollDominion.s.sol:FireScrollDominion \
  --rpc-url https://rpc.scroll.io --broadcast --slow --private-key "$SCROLL_PRIVATE_KEY"
```

Gate deploy tx: `0x8d20976a95486ca58dc1a6f79ff83128ffbb82196ec26d463257d779929a075b`  
Credit deploy tx: `0xcd7e5c0e4d847d5498551dd36ef9c55632b86621b6450172a3ddbb1b70934039`
