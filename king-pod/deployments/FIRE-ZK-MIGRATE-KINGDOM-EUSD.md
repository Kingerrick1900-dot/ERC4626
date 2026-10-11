# FIRE — Bring Kingdom eUSD under ZK / Safe

**Status:** ARMED · gas-blocked on HOT · V3 stub cannot fire  
**Branch doctrine:** One wallet at a time · `onBehalf = Safe` · `ZK_SHIELD = 1`

## Live facts (Base)

| Item | Value |
|--|--|
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Kingdom gUSD (7.06B eUSD reserve) | `0x319A49BB274A826F889C6e7221FA82f24ac8bc5d` |
| CrownZkMorphoRail | `0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3` · ~1.925B supplied |
| Safe | `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0` · `isProven=true` |
| Borders | `bordersSecure=true` |
| Executor V3 | `0x184e4Ad4678E7E05D174AAD490462620e225a9a3` |

## `migrateFirst100M()` — V3 result

Call as Safe (only authorized caller) **reverts `AwaitHandoff` (`0x587401c6`)**.  
The deployed V3 function is an intentional stub: it never supplies, never emits a capacity event, and does not touch `0x319A…`.

## Truth of the 7.06B “wallet”

`0x319A…8bc5d` is **Kingdom Gold USD (gUSD)** — not a free EOA.

- `gUSD.totalSupply()` = `eUSD.balanceOf(gUSD)` = **7,063,908,663.50** (1:1 reserve)
- HOT holds **~2,033,908,663.50 gUSD** → unwrap-reachable eUSD
- Pool `0x8C009d9654247Bc2B68DE98b3083B27aF8f2eFE7` (**Stable AMM — gUSD/eUSD**) holds **5,000,000,000 gUSD** + **5,000,000,000 eUSD** → **external public float / Ocean LP**

Migrating the full 7.06B reserve requires burning/unwrapping **all** gUSD (including the 5B in the AMM). Kingdom free path without draining the AMM: **HOT unwrap**.

## External classification (confirmed)

| Address | eUSD | Class |
|--|--:|--|
| `0x8C009d9654247Bc2B68DE98b3083B27aF8f2eFE7` | 5,000,000,000 | **External** — Stable AMM gUSD/eUSD (public float) |
| `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` | 1,810,391,357.90 | **External** — Morpho (includes Safe ZK seat) |
| `0x7d41ac987f8952617cca165e7d93576107ed1863` | 500,002.56 | **External** — Uni V3-style pool |
| `0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666` | 0.14 | **External** — Uni eUSD/USDC fee 500 |

## Real first-tranche path (fork-proven)

Script: `script/FireZkMigrateGusdFirst100M.s.sol`

1. HOT `gUSD.unwrap(100_000_000e18, HOT)`
2. HOT `eUSD.approve(ZK_RAIL, 100M)`
3. HOT `ZK_RAIL.zkSupply(100M, Safe)` — requires `isProven(HOT)` + `isProven(Safe)` + `bordersSecure`

Fork test `test/SimMig100.t.sol` **PASS** (~311k gas).

## Gas blocker (live) — broadcast attempted

| Wallet | ETH |
|--|--:|
| HOT | `879497749444` wei (~0.00000088) |
| Landing | ~0.000023 (no key in agent) |
| Safe | 0 |

Forge broadcast estimate for first 100M: **~0.00000427 ETH** (`want 2495900420000` wei).  
HOT shortfall: ~0.0000034 ETH. Error: `insufficient funds for gas * price + value`.

Simulation (no broadcast) logged success path: rail would go `1.925B → 2.025B`, HOT gUSD `2.033B → 1.933B`.

**Need ≥0.001 ETH on HOT** (comfortable for 100M + scale chunks) — Landing → HOT tip — then:

```bash
cd king-pod
FIRE_ZK_MIGRATE_GUSD_100M=1 forge script script/FireZkMigrateGusdFirst100M.s.sol:FireZkMigrateGusdFirst100M \
  --rpc-url $BASE_RPC --broadcast --legacy -vvv
```

## Scale order (after first 100M verifies)

From HOT gUSD balance remaining (~1.933B after first 100M):

1. 500M unwrap → zkSupply  
2. 1B → zkSupply  
3. remainder HOT gUSD → zkSupply  
4. Then HOT-owned contracts with free eUSD (`0xAb2162…`, `0x4C021c…`, `0xC28E7f…`, dust) — one wallet at a time  
5. Do **not** migrate AMM `0x8C009d…` (external float)

## Stop line

No migration broadcast this turn — executor stub + HOT gas. Fork path green. Waiting ETH on HOT.
