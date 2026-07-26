# Scroll Dominion — Elepan-native sovereign credit

**Base stays intact.** This is a parallel domain. ELE inventory remains on Base hot.  
On Scroll, **Elepan is the ruleset**: attested credit capacity → completer → Landing.

## Doctrine

| Domain | Role |
|--|--|
| **Base** | Hold position (ELE). Morpho = optional venue under Morpho rules. |
| **Scroll** | Elepan-native credit engine. ZK/sovereign attestation is first-class. |

## Live addresses (Scroll · chainId `534352`)

| Piece | Address |
|--|--|
| Hot (deployer / king) | `0xca76AE9e29a5F01465D890dc30109cD58B78F864` |
| Landing | `0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f` |
| USDC | `0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4` |
| Gate | *(set on fire)* |
| Credit | *(set on fire)* |
| Completer | *(set on fire)* |
| eUSD | *(set on fire)* |
| Spoils dominion | *(set on fire)* |

## Parameters

| Param | Value |
|--|--|
| Attested capacity | **$1,000,000,000** (6dp) — Base ELE notional @ kingdom $10 |
| minThreshold | **$700,000** |
| Credit LLTV | **70%** of attestation → maxAsk **$700,000,000** |
| TTL | 30 days |

## Fire (Scroll RPC only)

```bash
KING_GO=1 FIRE_SCROLL_DOMINION=1 \
SCROLL_PRIVATE_KEY=… \
forge script script/FireScrollDominion.s.sol:FireScrollDominion \
  --rpc-url https://rpc.scroll.io --broadcast --slow --private-key "$SCROLL_PRIVATE_KEY"
```

## Spoils path

Matcher/desk supplies Scroll USDC into credit via `completer.complete(amount)` → Landing receives.  
No Morpho. No Base write. Elepan honors the attestation natively.

## Isolation check

After deploy, Base hot ELE balance must be unchanged. Scroll scripts never target chain 8453.
