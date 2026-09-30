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

### Smart-contract bots (wire only)

| Env | Address |
|--|--|
| HUNT_ROUTER | `0xc4c63f8CD4182452f665e338F87b4d31aeF04516` |
| MULTI_ASSET_HUNTER | `0xE4900bfc340eE083C113211A51d1207A518fC2b2` |
| SPOIL_FIRE | `0xcFF60f3B071c09C17853bA715ceDc0Fc2e6645Fa` |
| CHUNK_FREER | `0xcFEaEC4eD07559963b0dc21aD46517e3bb9B823A` |

On box: `~/.king/SC-BOTS.md` · `BOTS_ARMED=0` (no hunt loops).  
Live: HuntRouter `killSwitch=false` · HOT + MultiAssetHunter are hunters — **FIRED** — see `FIRE-BOTS-LIVE.md` (smoke×3 + hunt pulse).

**Do not commit keys.** Rotate any key that appeared in chat.
