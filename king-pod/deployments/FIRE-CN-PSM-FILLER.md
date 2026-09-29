# FIRE — CrownPSMFiller (atomic closer)

**Mode:** FIRE · executed on Base  
**Door:** `CrownLsrEusd.sellGem` — USDC in, eUSD out, gem stays in LSR  

---

## Live

| Item | Value |
|--|--|
| **CrownPSMFiller** | [`0xe93737c5275CEa3A90cEB0A28A7A0873dc107150`](https://basescan.org/address/0xe93737c5275CEa3A90cEB0A28A7A0873dc107150) |
| LSR (PSM) | `0x3edeD70F8ACa4472948E7D3AE3Ad95D63ECdda4F` |
| KingAgent | `0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA` |
| SpendVault | `0xc3f2ACe4161B82dbceE08Ea636467D2C3bD72458` · target allowlisted |
| **LSR USDC after dust fill** | **1** (was 0) — sellGem proven live |

---

## What fired

1. Deploy filler (Morpho flash + UniV3 repay path wired).  
2. `setAgent` / `setOperator(agent,vault)` · vault `setTarget(filler)`.  
3. Dust `fill(USDC, 1)` from HOT → **LSR USDC 0 → 1**.  

---

## Tests

| Suite | Result |
|--|--|
| `PsmFillerTest` | **2/2 PASS** (fill + flash mock exit) |
| `PsmFillerForkTest` | **1/1 PASS** — fork: deal \$1k → LSR USDC ↑ by \$1k |

---

## Arm (auto)

```
agent.exec(filler, USDC, amt, abi.encodeCall(CrownPSMFiller.fill, (USDC, amt)))
```

`flashFill` when eUSD→USDC UniV3 depth covers Morpho repay (pools thin today — filler ready).

---

## One-block

```
FIRE=CrownPSMFiller 0xe93737c5…7150
SELLGEM=live · LSR_USDC=1
FORK=USDC↑ proven · AGENT+VAULT armed
NEXT=size fills when USDC inbound / flash when exit deep
```
