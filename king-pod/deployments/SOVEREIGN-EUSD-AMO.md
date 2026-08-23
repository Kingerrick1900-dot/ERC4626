# Sovereign eUSD AMO — RSS/eUSD/$1200

Frax-style AMO: Landing supplies **minted eUSD** unmatched on Morpho; borrow eUSD vs RSS at **$1200** oracle.

## Deploy (Base)

```bash
forge script script/DeploySovereignAmo.s.sol:DeploySovereignAmo \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Saves: `oracle`, `amo`, `scribe`, `marketId` from logs.

## Fire — full 100M supply

```bash
FIRE=1 AMO=<amo> SCRIBE=<scribe> SKIP_GATE=1 POST_COLL=1 \
  SUPPLY_AMT=0 RSS_AMT=0 BORROW_AMT=<optional> \
  forge script script/FireSovereignAmo.s.sol:FireSovereignAmo \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

- `SUPPLY_AMT=0` → full Landing eUSD balance (~100.7M)
- `POST_COLL=1` → post all free RSS from hot
- `SKIP_GATE=1` → disable pack gate for fire (re-enable after refresh)
- `BORROW_AMT` → eUSD to hot (size to HF / LLTV)

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
