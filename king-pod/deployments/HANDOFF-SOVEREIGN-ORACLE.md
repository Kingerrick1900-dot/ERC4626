# HANDOFF — Sovereign Oracle (CrownOracle)

**Operation:** Sovereign Oracle deployment + new RSS/USDC Morpho market  
**Target:** Base mainnet · **chainId `8453`**  
**Authority:** King HOT `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
**Status:** **FIRED on Base** — see `FIRE-SOVEREIGN-MIGRATE.md`  
Oracle `0x22E2…f2d` · market `0x1293…2f7b` · migrator `0xAbE2…Be24` · migrate **held** (`TreasuryShort` · need ~$22.8M USDC delta)

Migration proof: `deployments/SOVEREIGN-MIGRATION-RECORD.md` · test `test_sovereign_migration`

---

## Directive (King command)

| Requirement | Implementation |
|--|--|
| Full command | `setPrice(uint256)` · `onlyOwner` · HOT only |
| Adjust at will | No timelock · no governance · instant |
| Immutable authority | `owner` = HOT at `constructor` · `transferOwnership` only by owner |
| Morpho interface | `price()` external view |
| Secure | Custom errors · zero-price rejected |

**Contract:** [`src/CrownOracle.sol`](../src/CrownOracle.sol)  
**Deploy script:** [`script/DeploySovereignOracle.s.sol`](../script/DeploySovereignOracle.s.sol)  
**Tests:** [`test/CrownOracle.t.sol`](../test/CrownOracle.t.sol)

---

## Morpho price scale (RSS / USDC)

Morpho price = loan raw units per 1 collateral wei × **1e36**.

For **$P** USD per 1 RSS (USDC 6dp · RSS 18dp):

```
price_morpho = P × 1e24
```

| USD / RSS | Morpho `price()` |
|--:|--:|
| $1,200 | `1200000000000000000000000000` |
| **$50,000** (default deploy) | `50000000000000000000000000000` |

---

## New market (not the legacy book)

| Field | Value |
|--|--|
| Morpho Blue | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| IRM | `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** (`770000000000000000`) |
| Oracle | **new** `CrownOracle` (address at fire) |

**Market id** = `keccak256(abi.encode(MarketParams))` — logged by deploy script after `createMarket`.

### Legacy position (audit truth)

The **252,000 RSS** borrow book on market `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` uses **immutable** oracle `0xB5840644142B341a6145335e2ebc82EEBC7aE1B9` ($1,200, no setter). **Deploying CrownOracle does not reprice that market.** Securing LTV on the legacy book requires **on-chain migration** (repay / withdraw collateral / re-supply on the new market) or separate engineering — not oracle deploy alone.

See: `AUDIT-252K-RSS.md` · `ORACLE-50K-COMMAND-RECORD.md`.

---

## Fire (King / HOT only)

**Gate:** `FIRE_SOVEREIGN_ORACLE=1` · signer **`HOT_KEY`** must derive **`0x6708…a7d1`**.

```bash
cd king-pod
export BASE_RPC_URL=https://mainnet.base.org
export HOT_KEY=...   # King HOT — never commit

# Default initial price $50,000 / RSS
FIRE_SOVEREIGN_ORACLE=1 HOT_KEY=$HOT_KEY \
  forge script script/DeploySovereignOracle.s.sol:DeploySovereignOracle \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --with-gas-price 6000000

# Or explicit USD:
FIRE_SOVEREIGN_ORACLE=1 HOT_KEY=$HOT_KEY ORACLE_PRICE_USD=50000 \
  forge script script/DeploySovereignOracle.s.sol:DeploySovereignOracle \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --with-gas-price 6000000

# Oracle only (skip createMarket):
FIRE_SOVEREIGN_ORACLE=1 HOT_KEY=$HOT_KEY SKIP_CREATE_MARKET=1 \
  forge script script/DeploySovereignOracle.s.sol:DeploySovereignOracle \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --with-gas-price 6000000
```

**Dry-run (no broadcast):** omit `FIRE_SOVEREIGN_ORACLE=1` — script reverts at gate (intentional).

---

## Post-fire checklist (scribe)

After broadcast, paste into this file:

| Item | Value |
|--|--|
| CrownOracle address | _pending_ |
| Deploy tx | _pending_ |
| Block | _pending_ |
| Initial `price()` | _pending_ |
| New market id | _pending_ |
| `createMarket` tx | _pending_ |
| Live `idToMarketParams` match | loan/coll/oracle/lltv |

Then:

1. `cast call <oracle> "price()(uint256)" --rpc-url $BASE_RPC_URL`  
2. `cast call $MORPHO "idToMarketParams(bytes32)(...)" $MARKET_ID`  
3. If migrating legacy RSS: plan repay + `supplyCollateral` on **new** id — separate fire record.

---

## Deployed addresses (fill on fire)

```
CROWN_ORACLE=
CROWN_ORACLE_DEPLOY_TX=
MARKET_ID=
CREATE_MARKET_TX=
INITIAL_PRICE_USD=50000
INITIAL_PRICE_MORPHO=50000000000000000000000000000
OWNER=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
FIRE_SOVEREIGN_ORACLE=0
```

---

```
HANDOFF_SOVEREIGN_ORACLE=READY
CONTRACT=CrownOracle.sol
CHAIN=8453
AUTHORITY=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
DEFAULT_PRICE_USD=50000
LEGACY_MARKET_UNCHANGED=0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
NEXT=King_FIRE_SOVEREIGN_ORACLE=1
```
