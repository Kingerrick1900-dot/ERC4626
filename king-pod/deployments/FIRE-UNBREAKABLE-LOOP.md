# FIRE — Unbreakable Loop (No Dry-Run · Full Send)

**Mode:** FIRE · Base  
**Doctrine:** Kill the 10k dry-run. The machine runs the loop, the gates, the exit, and the scale. The King arms once.

---

## Fire 1 — Loop #3 & #4 ($1M each)

| # | Flash | Tx | Result |
|--|--|--|--|
| **3** | $1,000,000 | [`0xb37415c9…7c86`](https://basescan.org/tx/0xb37415c9a5553a9d0373dfcab4300920ca76cd37264170627740d93978237c86) | fires=3 · flashed=$2.1M |
| **4** | $1,000,000 | [`0x0f33fee2…efce`](https://basescan.org/tx/0x0f33fee2c78d104f75881537f157b52f86a7e7999946498b2b16396e4602efce) | fires=4 · flashed=$3.1M |

| Meter | Live |
|--|--|
| Morpho market depth | **≈ $3,100,012** |
| HOT Morpho collateral | **≈ 3,676,754 eUSD** |
| HOT wallet USDC | **$1.317180** (flash-closed) |
| Loop | [`0xedBb3bCF…5D3a`](https://basescan.org/address/0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a) |

Script: `FireCrownLoopNativeResume.s.sol` · **no dry-run**.

---

## Gate A — PASSED (contract)

Depth > $2M → `gateAPassed = true` on [`CrownUnbreakableGate`](https://basescan.org/address/0x60d56fADAc4e400087394F15AbAB61A05AB5902C).

---

## Fire 2 — Exit · Gate B LOCKED (honest)

| Check | Value |
|--|--|
| Exit USDC inventory | **$0** |
| Target | > $500k HOT USDC |
| `assertCanExit()` | **reverts `Inventory`** |
| `gateBPassed` | **false** |

CrownExitNative cannot mint Circle USDC. Inventory must be funded before Exit clears Gate B. No fake $500k.

---

## Fire 3 — Flywheel ARMED (both sides)

| Side | Script | Status |
|--|--|--|
| Lender | `ysynth_first_lender_boost.sh` | Gate B locked · waiting ySYNTH ≥ $1M + Exit |
| Borrower | `ysynth_borrower_boost.sh` | Gate B locked · waiting $5M external borrow + Exit |

Both scripts refuse pay until `GATE.assertCanFlywheel()` passes.

---

## Fire 4 — Scale ARMED (blocked on Gate B)

`FireCrownLoopScale.s.sol` — min $10M flash. Requires `assertCanScale` (Gate B + Dilithium + `armScale` cap).  
Private relayer: set `PRIVATE_RPC` when available; Base public mempool is the honest default today.

---

## Armor (live)

| Module | Address | Role |
|--|--|--|
| **CrownUnbreakableGate** | [`0x60d56fAD…902C`](https://basescan.org/address/0x60d56fADAc4e400087394F15AbAB61A05AB5902C) | Gate A/B · kill · scale arm |
| **CrownLoopScoreboard** | [`0xf38b3a83…Bbe7`](https://basescan.org/address/0xf38b3a838ae15487129905150FA00429Fa82Bbe7) | On-chain dashboard |
| Stark commit | [`0x10feb375…6e0c`](https://basescan.org/tx/0x10feb37565184c5efea0f5c171f2d888deeb371504d59f2a1fde8673869b6e0c) | Dilithium-era intent root |
| Dilithium | active on PqRegistry | quantum sign |
| Aave sleeve | `0x90ae…cb47` | kill → rescue route signal |
| Attest bind | **NotOwner** from Stark bridge | commit-only armor (honest) |

### Kill switch (auto-pause)

- yRSS share depeg > 5% vs baseline  
- Morpho depth < $1M  
- Full util **and** depth < Gate A → pause + `RescueToAave` event  

Self-seed util ≈ 99.99% alone does **not** kill (by design).

---

## Scoreboard (on-chain · `board.read()`)

```
FIRE=unbreakable-loop
LOOP_FIRES=4 totalFlashed=$3.1M depth≈$3.1M
GATE_A=true GATE_B=false
HOT_USDC=$1.317180 EXIT_INV=$0
YSYNTH=$1.330506
NEXT=fund Exit inventory >$500k USDC → confirmExit → flywheel → armScale → $10M/$50M/$200M
```

```bash
GATE=0x60d56fADAc4e400087394F15AbAB61A05AB5902C
BOARD=0xf38b3a838ae15487129905150FA00429Fa82Bbe7
cast call $GATE "scoreboard()(uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bool,bool)" --rpc-url $BASE_RPC
cast call $BOARD "read()((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bool,bool,uint256,uint256,uint64))" --rpc-url $BASE_RPC
```
