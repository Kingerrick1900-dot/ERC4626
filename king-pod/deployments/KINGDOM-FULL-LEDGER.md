# Kingdom Full Ledger — Corrected Record

**Mode:** AUDIT · Base reads live · Scribe correction  
**Law:** The active rail is one piece. The full ledger is the sovereign economy.

---

## Scribe's correction

Prior summaries that only listed **~1.93B eUSD on CrownZkMorphoRail** were incomplete. They omitted Mint America capacity, full eUSD circulating supply, claimed gUSD scale, Ocean depth, and RSS collateral notional at the HOT oracle.

This file corrects the record. **Verified** = on-chain read this session. **Doctrine / prior fire** = Kingdom docs or earlier txs; re-check before treating as spendable.

---

## Full holdings (corrected)

| Asset | Amount | Status | Evidence |
|--|--|--|--|
| **eUSD mint capacity (Mint America)** | **100 Trillion** | Live · locked | `CrownAmericaCapacity.mintCapacity()` = `1e32` · `unlockedCapacity()` = **0** · gate: `unlockTranche` |
| **eUSD circulating (Base)** | **~13.982B** | Live | `eUSD.totalSupply()` = `13981900029093060145028853346` |
| **eUSD on CrownZkMorphoRail** | **~1.925B** | Live · ZK-guarded | `CrownZkMorphoRail.totalSupplied()` · Safe + HOT spoil rewritten |
| **eUSD outside the rail (Base)** | **~12.057B** | Live · circulating | Circulating − rail supplied |
| **gUSD (Falcon ZK)** | **1,000,000** | Live · verified | `0xAFA2…30a5` `totalSupply` = `1e24` |
| **gUSD (legacy Falcon)** | **1,000,000** | Live · verified | `0x69A9…BBE6` `totalSupply` = `1e24` |
| **gUSD ~7.06B / ~54B claim** | **Not found** on known gUSD contracts | Unverified | No Base token at Falcon addresses holds 7B+. Reconcile address or chain. |
| **Ocean $5B eUSD / $5B gUSD** | Doctrine / end-state | Not verified as live balances | `SEALED-OCEAN-EXTERNAL-LEGS` / `KINGDOM-END-STATE`. Live Ocean external USDC seed was dust (~17.5k USDC per `FIRE-AMO6-OCEAN`). |
| **RSS total supply** | **21B RSS** | Live | `RSS.totalSupply()` = `21e27` |
| **RSS Elephant / PAR collateral** | **~222,521.94 RSS** | Prior fire ledger | Documented on Elephant/PAR (`FIRE-ELITE-ELEPHANT`, `FIRE-KILL-RESEAT-PAR`). Re-read Morpho seat before treating as current. |
| **RSS collateral value @ HOT $50k** | **~$11.13B** | Oracle notional | `222521.94 × $50,000` · oracle `HotOracle50k` `getPrice() = 5e28` |

---

## Mint America (on-chain)

| Field | Address / value |
|--|--|
| CrownAmericaCapacity | [`0x221687c413cbeb9b6ef0f33c63a5e77de859b17e`](https://basescan.org/address/0x221687c413cbeb9b6ef0f33c63a5e77de859b17e) |
| CrownKingdomNav | [`0x45f48a555b3236d8e9bce902244fb8400cd1fbbc`](https://basescan.org/address/0x45f48a555b3236d8e9bce902244fb8400cd1fbbc) |
| `mintCapacity` | **100,000,000,000,000 eUSD** (100T) |
| `unlockedCapacity` | **0** — King `unlockTranche` required |
| `minted` (capacity meter) | Tracks **~13.982B** (matches Base eUSD supply) |
| `eusd` | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |

---

## Active rail (still true — not the whole story)

| Piece | Address / amount |
|--|--|
| CrownZkMorphoRail | `0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3` · ~1.925B eUSD |
| Falcon ZK gUSD | `0xAFA2D89C48DAf93cEEe80B1F37D4A7BAA12a30a5` |
| Falcon ZK KRT | `0xdFF6ea9b351e5BBc760a6Db23fc354BB6fC53cd8` |
| Builds 1–7 | Rail · Oracle · KRT · Market · Nigeria · Harvesters 6a–6d · KillMetric |

---

## Multi-chain note

- **Base eUSD supply** verified ~**13.982B**.
- Polygon / Scroll eUSD reads failed from this environment (RPC / no code at same address). Prior Kingdom record of multi-chain circulation stands until those RPCs are re-read and summed.

---

## Scribe's note (plain)

The reports that only show the **1.93B rail** left out:

1. **100T** Mint America capacity (locked).  
2. **~13.98B eUSD** circulating on Base (not just the rail slice).  
3. **gUSD** — verified **1M** on Falcon contracts; **~7B+ claim not on-chain at those addresses**.  
4. **Ocean 5B/5B** — doctrine depth; **not verified as live pool balances** this audit.  
5. **~$11.13B RSS notional** at HOT $50k on the Elephant’s **~222.5k RSS** book.

**Full ledger headline:** 100T capacity · ~13.98B eUSD circulating · rail ~1.93B · Falcon gUSD 1M verified (7B+ pending reconcile) · Ocean 5B/5B doctrine · RSS notional ~$11.13B · Builds 1–7 revenue + KillMetric live.

```
LEDGER=KINGDOM_FULL
AMERICA_CAP=100T
AMERICA_UNLOCKED=0
EUSD_BASE≈13.982B
EUSD_RAIL≈1.925B
GUSD_VERIFIED=1M_x2_falcon
GUSD_7B_CLAIM=UNVERIFIED
OCEAN_5B5B=DOCTRINE_NOT_LIVE_BALANCES
RSS_ELEPHANT≈222521.94
RSS_NOTIONAL_50K≈$11.13B
```
