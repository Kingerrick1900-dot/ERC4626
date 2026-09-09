# FIRE LIFT — Ocean 1B SIDE + P4 coll named

**Status:** FIRED · freeze partially lifted for P5 ocean scale + P4 name locked  
**When:** 2026-09-09

---

## Ocean — bigger SIDE (FIRED)

| | |
|--|--|
| Seeder | `0x5AE22813c4560fA28a3C2e4c7e918Da42904c099` |
| SIDE this fire | **1,000,000,000 eUSD / gUSD** (1B per side) |
| Mint | **2B eUSD** (wrap 1B → gUSD) |
| Aero pool | `0x8C009d9654247Bc2B68DE98b3083B27aF8f2eFE7` |
| Pool before | ~21M / 21M |
| Pool after | ~**1.021B / 1.021B** |
| LP to | Landing `0x5Adc…2357` |

Toward King ocean thesis (1B→5B): **~1.02B/side live**. Next SIDE can push to 5B.

```bash
KING_GO=1 FIRE_OCEAN=1 OCEAN=0x5AE22813c4560fA28a3C2e4c7e918Da42904c099 \
SIDE=3979000000000000000000000000 \
  forge script script/FireFakeIdleOcean.s.sol:FireOceanSeed \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

---

## P4 coll — NAMED

| Field | Value |
|--|--|
| **Collateral** | **cbBTC** `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` |
| Why | Deepest USDC idle Morpho book on Base (~**$195M** vs WETH ~$10.8M) |
| Market (USDC loan) | `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836` |
| LLTV | 86% |
| L2 ask | **$1.5M lasting USDC idle** on park `0x41c08085…` |
| Coll needed (approx) | ≥ **$1.5M / 0.86 ≈ $1.75M** cbBTC notional |
| **Source** | **PENDING King** — OTC / treasury / slice of USDC payroll |

### L2 fire (armed when coll source funded)

```
flash 1.5M USDC
→ engineerIdle/createIdle on PARK
→ supplyCollateral cbBTC + borrow USDC on cbBTC/USDC market
→ repay flash
→ minIdleBuffer = 1.5M
```

Kill: do not borrow park to repay.

---

## Still open

| Item | Status |
|--|--|
| P4 coll **source** (where cbBTC comes from) | King names before L2 broadcast |
| P1 Landing withdraw $2M eUSD | Needs **Landing key** |
| P3 Flash L6 ~$1.01M USDC payroll | Ready when King says fire |
| Ocean → 5B/side | Optional next SIDE ~3.979B |

---

## One-block

```
OCEAN LIVE 1.021B/1.021B Aero eUSD/gUSD
P4 COLL = cbBTC (market 0x9103c3b4…) source=PENDING
NEXT = fund cbBTC → L2 1.5M lasting USDC idle | OR P3 payroll | OR ocean→5B
```
