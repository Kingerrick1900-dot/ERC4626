# Full Loop — CrownCuratorNative + CrownExitNative (Path C)

**Mode:** FIRE · Path B/C sovereignty — not Path A waiting  
**Doctrine:** Mint · Curate · Earn · Exit. Quantum armor. No Circle required for the native loop.

---

## Five PSMs (named — no omission)

| # | Rail | Address | Role |
|--|--|--|--|
| 1 | **Classic PSM** | `0x064489A287448674AA1dC6fb740d2F518CBA75dA` | Legacy gem door |
| 2 | **Base multi-PSM** | `0xF7337A26d9456e42a36531A12036A4556EF1F987` | Multi-gem Maker-class |
| 3 | **CrownLsrEusd** | `0x3edeD70F8ACa4472948E7D3AE3Ad95D63ECdda4F` | `sellGem` live · cold sink |
| 4 | **CrownPSMFiller** | `0xe93737c5275CEa3A90cEB0A28A7A0873dc107150` | Atomic flash closer |
| 5 | **CIPSCorridor (CN)** | `CrownCIPSCorridor` (China desk) | eUSD↔USDC CN rail |

**Major stablecoin rails:** eUSD · gUSD · USDC · USDT (multi-PSM gem) · AxCNH (Ricardian) — plus hard exits **cbBTC · WETH**.

---

## Two contracts, one loop

1. **CrownCuratorNative** — Kingdom MetaMorpho-class vault · **asset = eUSD** · King curator  
2. **CrownExitNative** — quantum-gated swap vault · eUSD → **cbBTC / WETH / USDC** from hunt inventory  

### Flow

```
NFC tap → Dilithium receipt + Stark bind → mint ≤200M eUSD (gold-backed capacity)
  → CuratorNative.deposit → allocate Ocean / Pendle / Aave-sleeve
  → harvest eUSD yield → ExitNative.exit → HOT hard assets
  → scoreboard: HOT USDC + HOT cbBTC + HOT WETH
  → THEN open 0x8531 USDC tranche to Conflux/AnchorX/SBI (extra $9M/yr)
```

| Path | Meaning |
|--|--|
| A | Wait for foreign USDC |
| B | Sovereignty (native eUSD curator) |
| **C + Exit** | Complete loop — mint, earn, exit hard |

---

## Caps / armor

| Gate | Spec |
|--|--|
| Mint slice | **200M eUSD** (not full 1.52B / 100T) |
| Gold | yRSS **loan ≠ sell** |
| Quantum | `CrownPqRegistry` Dilithium · `CrownStarkSnarkBridge` |
| Easy Trigger | `CrownEasyTrigger` NFC one-shot |
| Capacity | `CrownAmericaCapacity` unlock tranche before mint |
| Foreign USDC curator | `0x8531…05b0` opens **after** native loop proves yield |
