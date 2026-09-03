# KINGDOM STACK — EXECUTED (gas cents)

**Law:** No flash. Own exchange + own bank rails.

## 1) Own exchange — LIVE

| | |
|--|--|
| Pool | `0x8C009d9654247Bc2B68DE98b3083B27aF8f2eFE7` |
| Pair | eUSD / gUSD stable |
| Depth | **20M eUSD + 20M gUSD** |
| LP | HOT |

- create: `0x6efa59e7e31698842fab2620cdd4b848b1ef69a9b854c356a524a27f52b1dcc2`
- seed 10M: `0x693896090ba893c16bbd730dc7b56775b5d7c23dfa19bae5f67ce0717ea4b9f6`
- deepen +10M: `0x77e6353510f069453cc4908096dff3a39891d23d2c810fafe4f1641e12218ecf`

## 2) Own bank rail — ARMED

| | |
|--|--|
| Morpho eUSD/USDC market | `0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366` |
| HOT eUSD collateral posted | **40M eUSD** |
| USDC liquidity in book | **0** (waiting inbound / PA) |
| yRSS PA maxIn | **$50M** already open |
| IdleTap → credit | `0xC9Ec2fE1148B1DdC978D8e4345560e5f57d5BaB2` → `0x5568…` |
| Credit operators | tap + borrow router **true** |

supplyCollateral tx: `0xab44b137acbcbdbf39adb67b4d15a428f71aa6eef8f7fcf3c185de29af81bb84`

## 3) Draw path — READY

When USDC hits Morpho book or HOT:
`FireFillCreditDrawCast.sh` → credit `0x5568…` → Landing.

## Remaining (not gas — inventory physics)

Foreign USDC must flow into Morpho eUSD market (PA / solvers / depositors). Collateral + PA door + tap + credit are live. Pool is live.
