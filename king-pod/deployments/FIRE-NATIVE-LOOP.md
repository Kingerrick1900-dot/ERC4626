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
| Aave-class sleeve | `0x3c55Ef84eE345e05B60039512daEd331a4d5C441` |
| **totalMinted** | **200,000,000 eUSD** |
| Dilithium | active on `CrownPqRegistry` |
| Stark | committed + attest epoch bound |
| Capacity unlocked | ≥ supply + 200M |

Allocation: Ocean 50% · Pendle 25% · Aave-sleeve 25% (post-mint `allocate`).

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

## Exit / scoreboard

Hunt funds `CrownExitNative.fundInventory(USDC|cbBTC|WETH)`.  
King `exit(eusdAmt, tokenOut, minOut, nfc)`.

```bash
CURATOR_NATIVE=0x8Cb11A67F9734143195b24D179749534099b7558 bash script/yield_ignition_scoreboard.sh
```

**King number:** HOT USDC · HOT cbBTC · HOT WETH.

Foreign USDC tranche `0x8531…05b0` opens when ready — not when forced.

```
FIRE=native-loop ✓
CURATOR=0x8Cb11A67…7558 minted=200M
EXIT=0x97bd6846…bB68
PATH=C mint→allocate→harvest→exit
PSMs=5 named
NEXT=fund Exit inventory · harvest · open foreign gate when ready
```
