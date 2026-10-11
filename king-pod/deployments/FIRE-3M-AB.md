# FIRE — $3M Routes A + B (Base)

**Mode:** FIRE · broadcast  
**Decree:** Fire the $3M A+B  
**Scoreboard:** HOT USDC hard balance

---

## Live contracts

| Piece | Address |
|--|--|
| **CrownRevenueSweep (A)** | `0xd22cBd6f87DA859295b94c50e9dEB75842a18570` |
| **CrownGoldConvert (B)** | `0x194f272CB9CFFD6B71C90A1cFdd5907a14E5923D` |
| ColdBuffer | `0xBb3c14bBacD639797cB5c537fde370d1b7195521` |
| kXAU | `0x76822B470DeC1b94Df4219727288e7a196224853` |
| Uni kXAU/USDC 0.3% | `0x47EBd710De9c0396AC44927A7CC3345F13b321A7` |

---

## What fired

### Deploy
| Tx | |
|--|--|
| Sweep create | [`0x4dbc8599…3033`](https://basescan.org/tx/0x4dbc859915fe34d4caae1134fbaf120bd09f6975b288e567380ec18662b03033) |
| Convert create | [`0x32d8c725…54db`](https://basescan.org/tx/0x32d8c725b7de728821480d0a1ebee359ae62f2fac9d9378859a7daea5a1554db) |

### Route B — gold rail → USDC
| Step | Detail | Tx |
|--|--|--|
| Mint kXAU for book | `+153062` oz (ceil for $1.5M @ $9.80) | [`0x7cfd6010…ff8e`](https://basescan.org/tx/0x7cfd601011d02d5ce8bc68582483089dfc0c0e9bf6e63d94501982c8f11fff8e) |
| **TWAMM #0** | `153062e8` kXAU escrowed · floor **$9.80/oz** · 7d window · target **$1,500,000** | [`0xbe180f52…4e40`](https://basescan.org/tx/0xbe180f5296d1c8ed974c788f155d4ddf6eee58195fc886ea493783f33e314e40) |
| **Uni convert** | sold `5` oz → **980331** USDC (6dp) to HOT | [`0xf134b965…b2e6`](https://basescan.org/tx/0xf134b965dbfbae0cf7ad8aa125659ae5c7d2d909d08c41e0e63c1507fdedb2e6) |

TWAMM state: `open=true`, `soldIn=0`, escrow on Convert = `15306200000000`.  
`filledUsdc` (incl. Uni) = **980331**.

### Route A — revenue sweep
| Step | Detail |
|--|--|
| Fee sources allowlisted | Landing · KingVault · DeepPull · HOT |
| Sweep | **980331** USDC from HOT → **294099** Cold (30%) + **686232** HOT (70%) |

Tx: [`0xca78e3f9…4684`](https://basescan.org/tx/0xca78e3f98c85965f390ffaaa9b18f901d620765a5149af49ab00bdda832a4684)

---

## Scoreboard (post-fire)

| Meter | Raw (6dp) | USD |
|--|--:|--:|
| **HOT USDC** | **686232** | **$0.686232** |
| ColdBuffer USDC | 294099 | $0.294099 |
| Route B filled (cum) | 980331 | $0.980331 |
| TWAMM notional booked | 1_500_000e6 | **$1,500,000** @ $9.80 ask |

Ocean **external-leg** $1.5M USDC seed: **not fired** — needs acquired HOT USDC (TWAMM fills). Law: no AMO on self-paired Ocean alone — see `SEALED-OCEAN-EXTERNAL-LEGS.md`.

---

## Physics (honest)

1. **TWAMM $1.5M ask book is live** — first external fill pays USDC straight to HOT (max $150k/fill).  
2. **Atomic Uni path** cleared the only kXAU/USDC pool inventory (~$1). No deeper Uni bid exists.  
3. **Route A pipe is live** — every future fee USDC splits 30/70 Cold/HOT.  
4. yRSS `maxWithdraw=0`; Morpho GOLD idle ≈ $1; no King gold Morpho borrow.

```
SWEEP=0xd22cBd6f87DA859295b94c50e9dEB75842a18570
CONVERT=0x194f272CB9CFFD6B71C90A1cFdd5907a14E5923D
TWAMM_ID=0
TARGET_USDC=1500000000000
SCOREBOARD_HOT_USDC=686232
NEXT=TWAMM fills → HOT USDC ↑ → Ocean seed when leg funded
```
