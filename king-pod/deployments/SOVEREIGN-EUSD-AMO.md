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

## Fork proof

```bash
forge test --match-contract SovereignAmoForkTest -vv
```

## Physics

| Step | Effect |
|--|--|
| `supplyAmo` | Unmatched eUSD idle = supply |
| `postCollateral` | RSS posted, no borrow |
| `borrowEusd` | Pulls from idle; gate when `requireGate` |

No USDC. No desk. No matched loop in supply tx.
