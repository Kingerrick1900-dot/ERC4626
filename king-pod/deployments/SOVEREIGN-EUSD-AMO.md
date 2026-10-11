# Sovereign eUSD AMO — RSS/eUSD/$1200

Frax-style AMO: Landing supplies **minted eUSD** unmatched on Morpho; borrow eUSD vs RSS at **$1200** oracle.

## LIVE (Base mainnet — fired 2026-08-23)

| | |
|--|--|
| Oracle | `0x4153669Cc3671B6b8b68D47Fd852Ad1a48b950e0` |
| Market ID | `0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599` |
| AMO | `0x151C947B813400fE78EE176843F2d666c07422eA` |
| Scribe | `0xFAE5a8065d81c308395E050d737fA7a5b2b23160` |
| Exit | `0x937Ba9eA3288781851E19Df50D33b800b10F064b` |

| Leg | Amount |
|--|--|
| Landing eUSD supply | **100,700,027 eUSD** |
| HOT RSS collateral | **~9.60M RSS** (all free) |
| HOT eUSD borrow | **8,850,000 eUSD** |
| Unmatched idle | **~91.85M eUSD** |

Exit authorized on Morpho for HOT + Landing.

## Deploy (Base)

```bash
AMO_OWNER=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357 \
PRIVATE_KEY=<hot_key> \
forge script script/DeploySovereignAmo.s.sol:DeploySovereignAmo \
  --rpc-url $BASE_RPC_URL --broadcast --slow --with-gas-price 6000000
```

## Fire — full supply + collateral + borrow

```bash
AMO=0x151C947B813400fE78EE176843F2d666c07422eA \
SCRIBE=0xFAE5a8065d81c308395E050d737fA7a5b2b23160 \
SKIP_GATE=0 POST_COLL=1 \
SUPPLY_AMT=0 RSS_AMT=0 BORROW_AMT=8850000000000000000000000 \
LANDING_PRIVATE_KEY=<landing_key> \
PRIVATE_KEY=<hot_key> \
forge script script/FireSovereignAmo.s.sol:FireSovereignAmo \
  --rpc-url $BASE_RPC_URL --broadcast --slow --with-gas-price 6000000
```

Landing owner must call `setRequireGate(false)` first if gate still on.

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
