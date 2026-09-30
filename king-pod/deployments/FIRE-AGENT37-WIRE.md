# FIRE — agent37 Hermes WIRED

**Status:** LIVE · healthy  
**Instance:** `hs1r8hko0l`  
**URL:** https://hs1r8hko0l.agent37.app  
**Template:** `agent37-hermes` · image `hermes:2026.09.27b`  
**Resources:** 2 vCPU · 4 GB · 4 GB disk

---

## Wired on box

| Item | Path / value |
|--|--|
| Fire env | `/home/node/.king/fire.env` (mode 600) |
| Ops brief | `/home/node/KING-OPS.md` |
| Foundry | `/home/node/.foundry/bin` cast/forge **v1.8.3** |
| shellrc | PATH + auto-source fire.env |

### Tokens in `fire.env`

| Env | Address |
|--|--|
| **ELE / ELEPAN** | `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` (8dp · name elephanToken · symbol RSS) |
| ELEPAN_ZK_GATE | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| USDC · RSS(18) · eUSD · cbBTC · WETH | standard Base rails |

## Prove (Hermes turn)

HOT `0x6708e211…a7d1` · ETH `0.000142793426520125` · USDC **`$1.330485`**  
**ELE HOT:** **44,599,950.25012381** (8dp) · RSS(18) wallet `0` · gate codesize 1897

Auth via Hosting API `Authorization: Bearer sk_live_…` · Agent plane `X-Agent37-Key`.

```bash
AGENT37_KEY=sk_live_... INSTANCE_ID=hs1r8hko0l \
  HOT_KEY=0x... BASE_RPC=https://mainnet.base.org \
  bash script/wire_agent37.sh
```

**Do not commit keys.** Rotate any key that appeared in chat.
