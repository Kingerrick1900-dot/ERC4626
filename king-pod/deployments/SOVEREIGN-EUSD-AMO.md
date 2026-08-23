# Sovereign eUSD AMO — RSS/eUSD/$1200

Frax-style AMO: Landing supplies **minted eUSD** unmatched on Morpho; borrow eUSD vs RSS at **$1200** oracle.

## Predicted deploy (Landing nonce 31, sim 2026-08-23)

| Contract | Address |
|--|--|
| Oracle | `0x620260cA89f2b1558fdF7F3BC3E9ff2068345575` |
| Market ID | `0xecac60bed651edf8322c9e437e2b4d68b165d09fe82904bd8ef645bbf2bd0d87` |
| AMO | `0x6755D1Eb196B4C2510a3Ca053662304baE6f24c8` |
| Scribe | `0xD6A6e0eedf244db47f72294fD33DC1Db36463004` |
| Exit | `0x539efCDa0c18b494Ae9Be3E874776cd7149D7D1D` |

**Gas gate:** Landing needs **≥ 0.003 ETH** on Base for deploy + fire (had ~0.00027 ETH at attempt). HOT key still required for RSS collateral + borrow legs.

## Deploy (Base)

```bash
AMO_OWNER=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357 \
PRIVATE_KEY=<landing_key> \
forge script script/DeploySovereignAmo.s.sol:DeploySovereignAmo \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Saves: `oracle`, `amo`, `scribe`, `marketId` from logs.

## Fire — full 100M supply

```bash
AMO=0x6755D1Eb196B4C2510a3Ca053662304baE6f24c8 \
SCRIBE=0xD6A6e0eedf244db47f72294fD33DC1Db36463004 \
SKIP_GATE=1 POST_COLL=1 \
SUPPLY_AMT=0 RSS_AMT=0 BORROW_AMT=8850000000000000000000000 \
LANDING_PRIVATE_KEY=<landing_key> \
PRIVATE_KEY=<hot_key> \
forge script script/FireSovereignAmo.s.sol:FireSovereignAmo \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

- `SUPPLY_AMT=0` → full Landing eUSD balance (~100.7M) — **Landing key only**
- `POST_COLL=1` → post all free RSS from hot — **requires HOT key**
- `SKIP_GATE=1` → disable pack gate for fire (re-enable after refresh)
- `BORROW_AMT` → ~8.85M eUSD to hot at 77% LLTV — **requires HOT key**

Supply-only fire (Landing key alone): omit `POST_COLL` and `BORROW_AMT`.

## Exit — full unwind

```bash
EXIT=<exit> MARKET_ID=<mid> ORACLE=<oracle> \
  LANDING_PRIVATE_KEY=<landing key> \
  forge script script/FireSovereignExit.s.sol:FireSovereignExit \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

`exitFull()`: repay king eUSD debt → withdraw all RSS → recall all Landing supply. Reverts if any leg fails.

King must hold borrowed eUSD for repay. Landing + hot must `setAuthorization(exit, true)` on Morpho.

## Fork proof

```bash
forge test --match-contract SovereignAmoForkTest -vv
```

Includes `test_exit_full_roundtrip` — 100M supply, borrow, full exit, zero dust positions.

## Physics

| Step | Effect |
|--|--|
| `supplyAmo` | Unmatched eUSD idle = supply |
| `postCollateral` | RSS posted, no borrow |
| `borrowEusd` | Pulls from idle; gate when `requireGate` |

No USDC. No desk. No matched loop in supply tx.
