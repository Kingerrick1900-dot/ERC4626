# FIRE — CrownCuratorNative + CrownExitNative (Full Loop LIVE)

**Mode:** FIRE · Path C closed  
**Doctrine:** Mint · Curate · Earn · Exit. Five PSMs named. Quantum armor on.

---

## LIVE

| Module | Address |
|--|--|
| **CrownCuratorNative** | [`0x8Cb11A67F9734143195b24D179749534099b7558`](https://basescan.org/address/0x8Cb11A67F9734143195b24D179749534099b7558) |
| **CrownExitNative** | [`0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68`](https://basescan.org/address/0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68) |
| Pendle sleeve | `0x0322AfEc914C2283AEF0fa2e8b61f1e7e85d3429` |
| Aave-class eUSD sleeve | `0x3c55Ef84eE345e05B60039512daEd331a4d5C441` |
| **CrownAaveSleeve** (real USDC→Aave V3) | [`0x90ae3823d79175daB4095cF1Bf8C6dFB0c34cb47`](https://basescan.org/address/0x90ae3823d79175daB4095cF1Bf8C6dFB0c34cb47) |
| **totalMinted** | **200,000,000 eUSD** |
| Dilithium | active on `CrownPqRegistry` |
| Stark | committed + attest epoch bound |
| Capacity unlocked | ≥ supply + 200M |

Allocation: Ocean 50% · Pendle 25% · Aave-class eUSD sleeve 25% (post-mint `allocate`).

---

## Five PSMs

| # | Rail | Address |
|--|--|--|
| 1 | Classic PSM | `0x064489A287448674AA1dC6fb740d2F518CBA75dA` |
| 2 | Base multi-PSM | `0xF7337A26d9456e42a36531A12036A4556EF1F987` |
| 3 | CrownLsrEusd | `0x3edeD70F8ACa4472948E7D3AE3Ad95D63ECdda4F` |
| 4 | CrownPSMFiller | `0xe93737c5275CEa3A90cEB0A28A7A0873dc107150` |
| 5 | CIPSCorridor (CN) | China desk `CrownCIPSCorridor` |

---

## Exit / scoreboard — PROVED

ColdBuffer → Exit inventory → sleeve.pull eUSD → `ExitNative.exit` → HOT USDC → half Aave supply.

| Step | Tx / proof |
|--|--|
| Cold → Exit USDC seed | `2660969` USDC inventory on Exit |
| sleeve.pull | [`0x653764b9…4254`](https://basescan.org/tx/0x653764b98e286e9cbf923127956a614acf6f031de7aa2f1141601966cb6b4254) |
| eUSD approve | [`0x2c5831be…b5c0`](https://basescan.org/tx/0x2c5831be31a9e0db937bd5ea2e54116c02275c38da1c1f2808ec1ec78324b5c0) |
| **exit → HOT** | [`0x25dbcab…3323`](https://basescan.org/tx/0x25dbcabbd20c5f212946527730fcc918152a4f1374e8bc10b878aef4431a3323) · raw `2660969` = **`$2.660969`** (USDC 6dp — not $2.66M) |
| Aave sleeve deploy | [`0xf37d12f0…df66`](https://basescan.org/tx/0xf37d12f009a5d5055228a6c8e8a97ee64d4049a61631a39efe99e41a2a52df66) → `0x90ae…cb47` |
| Aave supply | [`0xdbf3f2ec…dda7`](https://basescan.org/tx/0xdbf3f2ecc8590227a5c12a4d16ad7bc85478587c32c168a86d30be3e5f2fdda7) · raw `1330484` = **`$1.330484`** aUSDC |

**Custody reconcile:** see `EXIT-FUNDS-RECONCILE.md` — King-controlled · not compromised · HOT `$1.330485` + sleeve aUSDC `~$1.330488`.

```bash
CURATOR_NATIVE=0x8Cb11A67F9734143195b24D179749534099b7558 bash script/yield_ignition_scoreboard.sh
# IGNITION=YES · hotUsdc≈1.33 · sleeve aUSDC≈1.33 · nativeMinted=200000000
```

**King number:** HOT USDC · HOT cbBTC · HOT WETH · Aave aUSDC on sleeve.

Foreign USDC tranche `0x8531…05b0` opens when ready — not when forced.

```
FIRE=native-loop ✓ CLOSED
CURATOR=0x8Cb11A67…7558 minted=200M
EXIT=0x97bd6846…bB68 exited=2660969 USDC
AAVE_SLEEVE=0x90ae3823…cb47 supplied=1330484
PATH=C mint→allocate→harvest→exit→aave ✓
PSMs=5 named
2035=see FIRE-2035-RUN.md (ZK+PQ+QKD+NFC fired · cold still 0)
NEXT=scale Exit inventory / open foreign gate when ready
```
