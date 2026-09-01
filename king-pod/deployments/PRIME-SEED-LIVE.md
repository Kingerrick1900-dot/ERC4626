# PRIME SEED — LIVE

**Status:** Phantom $4.5M debt **cleared from live stack** · router disarmed · idle still needs real USDC  
**Chain:** Base 8453

## Live state (now)

| Metric | Value |
|--------|-------|
| **Live credit debt** | **$0** |
| `coll.reservedDebtUsd6` | **$0** |
| Borrow capacity | **$11,000,000** |
| `credit.freeUsdc()` | **0** (no USDC in yet) |
| Landing USDC | **0** |
| `router.armed` | **false** |

## What we did

Poisoned credit could not wipe debt (no USDC, no upgrade). Replaced the pool.

| Piece | Address |
|-------|---------|
| **CrownPrimeCredit (LIVE)** | `0x5568fE662363d7F3fa52349A99C9e19C6616B60d` |
| **USDCBorrowRouter (LIVE)** | `0xBb3C372D4A0C398b6107f13ea4b1AB00B2b0A7aC` |
| **CrownPrimeIdleTap (LIVE)** | `0xC9Ec2fE1148B1DdC978D8e4345560e5f57d5BaB2` |
| Collateral (unchanged) | `0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8` |
| Fill (rewired) | `0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab` |
| LitePSM (rewired) | `0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B` |

Deploy tx (credit create): [`0xbef4445e…`](https://basescan.org/tx/0xbef4445e97b4737e9a28e39aa24d841aa551b0997b3546ea99b09ff0a015961d)

Old credit `0xc184A1d2…` still shows $4.5M on a **disconnected** contract. Fill/PSM/coll no longer use it.

New credit has `forgivePhantomDebt()` so this cannot trap the king again.

## Still true

Clearing phantom debt ≠ $4.5M USDC to spend. Payroll still needs **inbound USDC** (external 7683 fill, wire, or IdleTap when a Morpho book has idle).

## External 7683 order (solver fill → new credit idle)

```text
orderId   = 0xf686d8b64760ef692e4edbd480a3ca7db225a21a16eb60bfb7c99baa231631e9
maxUsdcIn = 4500000000000
Fill      = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
```

## Draw when idle > 0

```bash
DRAW_AMT=… PRIVATE_KEY=0x… bash king-pod/script/FirePrimeDrawCast.sh
```

## Disabled

Flash cast scripts exit 1. Do not self-flash.

**Rotate HOT key** — was used in chat.
