# FIRE — Sovereign Oracle + Market (migrate held)

**Mode:** FIRE · Base · chainId `8453`  
**Block:** **52196233–52196235**  
**Gate fired:** `FIRE_SOVEREIGN_MIGRATE=1` · `SKIP_MIGRATE=1` for deploy · migrate attempted → **`TreasuryShort()`**

---

## Live — fired

| Piece | Address / value | Tx |
|--|--|--|
| **CrownOracle** | `0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d` | [`0x124f4157…66bd`](https://basescan.org/tx/0x124f41576a58989c5a22dd48e01aa78203cb13607144787200fdcbbf7ab466bd) |
| owner | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` (HOT) | — |
| `price()` | `50000000000000000000000000000` = **$50,000 / RSS** | live @ 52196238 |
| **createMarket** | RSS/USDC · oracle above · LLTV 77% | [`0x0cd22c27…2a6e`](https://basescan.org/tx/0x0cd22c2726243c3261b658dd2e41829eaea26ca2e1d7484866cb972f730b2a6e) |
| **Market id** | `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b` | — |
| **CrownSovereignMigrate** | `0xAbE261A85beD1ABA1c77B58ef550E9c4192dBe24` | [`0x750f3ea0…cb17`](https://basescan.org/tx/0x750f3ea04b41a15216056af1966c6d9c391ca95af1e8cca7e7b2db669006cb17) |

`idToMarketParams` confirmed: loan USDC · coll RSS · oracle `0x22E2…f2d` · IRM AdaptiveCurve · LLTV 77%.

---

## Migrate — held (capital)

| Meter | Live |
|--|--:|
| Legacy debt | ~**$257,294,976** |
| Morpho USDC (flash max) | ~**$234,531,742** |
| **Treasury delta needed** | ~**$22,768,266** |
| HOT USDC Base | **$0.33** (`328834`) |
| HOT USDC Polygon | **$0.82** (`816015`) |
| yRSS `maxWithdraw(HOT)` | **0** |

Live `migrate()` reverts **`TreasuryShort()`** — fork path needs ~**$22.8M USDC** on HOT (flash + bridge).

Legacy 252k RSS still on `0x41c08085…7d88` (immutable $1,200 oracle).

---

## Resume migrate (when delta lands)

```bash
FIRE_SOVEREIGN_MIGRATE=1 HOT_KEY=$HOT_KEY \
  SOVEREIGN_ORACLE=0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d \
  SKIP_CREATE_MARKET=1 \
  forge script script/FireSovereignMigrate.s.sol:FireSovereignMigrate \
  --rpc-url $BASE_RPC_URL --broadcast --slow --with-gas-price 6000000
```

Or call `migrate()` on `0xAbE261…Be24` after: USDC + yRSS approve migrator · `Morpho.setAuthorization(migrator, true)`.

---

```
FIRE_SOVEREIGN_ORACLE=1
CROWN_ORACLE=0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d
MARKET_ID=0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b
MIGRATOR=0xAbE261A85beD1ABA1c77B58ef550E9c4192dBe24
PRICE_USD=50000
MIGRATE=HELD_TREASURY_SHORT
DELTA_USDC_NEEDED~=22768266
```
