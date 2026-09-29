# FIRE — KE-Sov Ricardian incorporation

**Mode:** FIRE · Base  
**Entity:** KE-Sov (King Errick Sovereignty)  
**Doctrine:** Legal person + on-chain settlement = one Ricardian document. Agents serve the King alone.

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
