# HANDOFF — King signs Falcon · Landing ~1.32B eUSD → Morpho rail

**Mode:** King signature path · Base  
**Doctrine:** Falcon stack under Kingdom Safe · Landing eUSD spoil becomes Morpho idle (not wallet paper)

---

## Live state (pre-sign)

| Book | Status |
|--|--|
| Gate `king()` | **Kingdom Safe** `0x23590FEb…eac0` · `pendingKing=0` · HOT operator **true** |
| Falcon stack owner | HOT (until King-sign fire) → **Safe** |
| HOT Morpho eUSD idle | **~301M** on rail `0xc61a…` |
| Landing wallet eUSD | **`1323450370221800120394502348`** (~1.323B) — **still parked** |
| Landing ETH | ~0.0000246 (enough for approve+supply @ current Base fees) |

---

## A — King signs Falcon (HOT executes crowning)

HOT transfers Falcon ownership → Safe (King). No Landing key needed.

```bash
FIRE_FALCON_KING_SIGN=1 ZK_SHIELD=1 \
  forge script script/FireFalconKingSign.s.sol:FireFalconKingSign \
  --rpc-url "$BASE_RPC" --broadcast --with-gas-price 5000000
```

| Contract | Must become owner = Safe |
|--|--|
| Oracle | `0xF98bfd64D04752aD39fFD404959db4A9Aa98086A` |
| KRT | `0xBFcEB59591e73eB589eEf767E2151a5c62175AB7` |
| gUSD | `0x69A9247457f31bF367C300e00D6fBA81da7cbBE6` |
| Harvester | `0xeDDb1bfDbF2d5A0a619C99Dcd1AF9E9A88627871` |
| Crown369 | `0xD75d8F6F10bfcF7cb52ed98a30e2A21a614c2925` |

Verify:

```bash
for C in \
  0xF98bfd64D04752aD39fFD404959db4A9Aa98086A \
  0xBFcEB59591e73eB589eEf767E2151a5c62175AB7 \
  0x69A9247457f31bF367C300e00D6fBA81da7cbBE6 \
  0xeDDb1bfDbF2d5A0a619C99Dcd1AF9E9A88627871 \
  0xD75d8F6F10bfcF7cb52ed98a30e2A21a614c2925
do cast call $C "owner()(address)" --rpc-url https://mainnet.base.org
done
# all → 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0
```

After this, mint/oracle/market ops need **Safe 2-of-3** (Landing + one other owner).

---

## B — What must happen with the ~1.32B on Landing

**One job:** move Landing eUSD from the wallet onto the Morpho spoil rail as **kingdom idle**.

| Step | Who | Action |
|--|--|--|
| 1 | Landing | `eUSD.approve(Morpho, amount)` |
| 2 | Landing | `Morpho.supply(eUSD/RSS market, amount, 0, Safe, "")` |
| 3 | Agent/King | Verify market idle ≈ 301M + 1.323B · Safe holds supply shares |

| Param | Value |
|--|--|
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| Market id | `0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599` |
| onBehalf | **Safe** `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0` (King custody of shares) |
| Amount | full balance (or King-chosen `SEED_AMT`) |

### Why this rail (not Falcon 38.5% yet)

- Same rail HOT already seeded — consolidates **one idle book**
- Falcon 38.5% markets stay ready for KRT/gUSD / later eUSD tranche; parking 1.32B on the live spoil rail maximizes immediate idle depth

### Path 1 — Agent fires when King seals `LANDING_PRIVATE_KEY`

```bash
# King adds LANDING_PRIVATE_KEY to sealed secrets, then:
FIRE_LANDING_EUSD_RAIL=1 \
  forge script script/FireLandingEusdRail.s.sol:FireLandingEusdRail \
  --rpc-url "$BASE_RPC" --broadcast --with-gas-price 5000000
# King deletes LANDING_PRIVATE_KEY immediately after
```

### Path 2 — Landing MetaMask (no key to agent)

1. MetaMask → **Landing** `0x5Adcea…2357` · network **Base**
2. Open `king-pod/tools/landing-eusd-rail.html` → Connect → **Approve eUSD** → **Supply to Morpho (Safe)**
3. Or Basescan Write Contract on eUSD / Morpho with the calldata below

```
approve(spender=Morpho, amount=1323450370221800120394502348)
supply(
  marketParams = idToMarketParams(0xc61a…0599),
  assets = 1323450370221800120394502348,
  shares = 0,
  onBehalf = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0,
  data = 0x
)
```

### What this is **not**

| Wrong move | Why |
|--|--|
| Leave in Landing wallet | Paper spoil — not rail idle |
| Transfer to HOT only | Re-creates single-key custody; skip unless temporary gas hop |
| Burn / mint games | Spoil is already minted inventory — supply it |
| Wait for USDC convert first | eUSD Morpho idle is Stage0 law; USDC is Stage1 China/PSM |

---

## After both A + B

```
FALCON_OWNER=Safe
LANDING_EUSD_WALLET=0
MORPHO_EUSD_IDLE~=1.624e9
ON_BEHALF_SHARES=Safe
NEXT=China Stage1 USDC liquidity + King sig on corridor · or seed PAR USDC for $4.28B draw
```

Say **check again** when Landing supply is confirmed.
