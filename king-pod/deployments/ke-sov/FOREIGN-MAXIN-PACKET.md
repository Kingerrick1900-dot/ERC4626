# Foreign maxIn packet — KE-Sov counterparty

**Doctrine:** Kingdom-owned PA caps can be set by HOT. **Foreign** vault maxIn requires curator action.

## Owned (HOT can set)

| Vault | Market | Action |
|--|--|--|
| yRSS `0xF80C…D525` | PARK RSS/USDC `0x41c08085…7d88` | `PA.setFlowCaps` maxIn/maxOut ≥ **$700k** (raise toward **$5M** under King) |
| yRSS | RSS book `0x40ac09f3…b794` | Keep / raise PA maxIn for PA pull → borrow |
| CrownPSMFiller `0xe93737c5…7150` | filler arm | Keep vault `allowedTarget`; KE-Sov settlement listed |

## Foreign (curator ask — KE-Sov signed)

| Vault | Address | Ask |
|--|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` | maxIn ≥ **$700k** on Kingdom RSS market |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` | maxIn ≥ **$700k** |
| Steakhouse USDC | `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` | maxIn ≥ **$700k** |

**Counterparty on the ask:** KE-Sov LLC · settlement Landing · Ricardian hash attached.

Agents **cannot** flip Gauntlet/Steakhouse storage. Packet is the fire.
