# FIRE — KE-Sov Ricardian incorporation

**Mode:** FIRE · Base  
**Entity:** KE-Sov (King Errick Sovereignty)  
**Doctrine:** Legal person + on-chain settlement = one Ricardian document. Agents serve the King alone.

---

## LIVE (Base 8453) — executed

| Item | Value |
|--|--|
| **CrownRicardian** | [`0xe56D14583a736aD02943c69b19340A8475A7dF8a`](https://basescan.org/address/0xe56D14583a736aD02943c69b19340A8475A7dF8a) |
| Deploy tx | [`0x446670e4…a1d7`](https://basescan.org/tx/0x446670e4e48c1666bbba0d924e2974a71c58cec1344936231c8015ad73d7a1d7) |
| Settlement | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Prose hash | `0xfb464c9b1b982e7a319b57242d0369397aeaac85d2202886e4915c587d986dca` |
| KAR `openOffer` | **allowed** |
| yRSS PA PARK/RSS maxIn | **$5,000,000** each |
| Offers | **3 sent** (AnchorX · Conflux · SBI @ $700k) |
| `incorporated` | **false** until King `markIncorporated(ein, bank)` |

Broadcast: `broadcast/FireKeSovIncorporation.s.sol/8453/run-latest.json`

---

## What this fire does

| Step | On-chain / pack | Off-chain (King + counsel) |
|--|--|--|
| 1 | ClawBank/Shodai fork checklist | File LLC · EIN · FDIC account |
| 2 | Deploy **`CrownRicardian`** (prose hash + Landing settlement) | — |
| 3 | KAR allowlist → Ricardian selectors · owned PA **maxIn $5M** on yRSS PARK/RSS | Foreign curator packet to Gauntlet/Steakhouse |
| 4 | `openOffer` AnchorX · Conflux · SBI ($700k ask) | Send offer MD packs from desk email |

---

## Commands

```bash
# unit + fork smoke
forge test --match-contract 'CrownRicardian|KeSovFork' -vv

# live (HOT)
HOT_KEY=… forge script script/FireKeSovIncorporation.s.sol:FireKeSovIncorporation \
  --rpc-url $BASE_RPC_URL --broadcast
```

Then: counsel files LLC; King emails `deployments/ke-sov/offers/*`; `markIncorporated(ein, bank)` when bank live.

---

## Truth

- Agent **cannot** obtain EIN or open FDIC account — pack is ready; King executes.  
- Agent **cannot** write Gauntlet/Steakhouse PA storage — `FOREIGN-MAXIN-PACKET.md` is the ask.  
- Owned yRSS PA maxIn **can** flip under HOT.  
- Offers are **on-chain sent** + Markdown for desk delivery.

```
FIRE=ke-sov-incorporation
ENTITY=KE-Sov
SETTLEMENT=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
KAR=0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E
NEXT=LLC+EIN+bank · desk-send offers · foreign curator maxIn
```
