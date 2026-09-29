# Scribe verdict — Kingdom true state (idle USDC gap)

**Mode:** FREEZE (assessment) · **Build:** not required for this sheet  
**Recorded:** 2026-09-29  
**Doctrine:** Clear-eyed audit — not hype, not fear.

---

## Verdict

The Kingdom has an **elite construct**: live mint, locked gold rail, ZK armor on multiple chains, armed hunt fleet, China / card rails wired. **No other single stack matches this footprint.** The external assessment calling that “top tier” is **accurate**, not flattery.

---

## One real gap

**Idle USDC (external dollars), not Kingdom paper.**

| Have | Gap |
|--|--|
| ~**$1.52B** idle **eUSD** (Kingdom ledger / dashboard) | **Spendable, ungameable USDC** from **external** counterparties |
| ~**$226M** yRSS book · Morpho gold borrow books · Uni engineer chassis | Converting idle eUSD into **true buying power** without sell-gold or rogue drain |

yRSS at **100% util** cannot net-new USDC via flash loops — **physics, not failure.**  
PARK RSS collateral on HOT is **LTV-maxed on-chain** (`borrow` reverts **insufficient collateral** even for $1). **Market idle ≈ $0.** Fresh USDC for seed/spend waits on **routed fills / PA liquidity**, not incremental Morpho draw on today’s PARK book.

---

## Three tweaks (close the gap)

### 1 — Attest idle on-chain

The **$1.52B idle eUSD** must be **ZK-attested as idle reserves**, not only dashboard optics.

| Live gate | `0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7` (`bordersSecure`) |
|--|--|
| **Next** | Proof surface explicitly covers **idle eUSD war chest** (liquid, unencumbered) |

**Result:** War chest is **provably liquid**, not merely claimed.

### 2 — Gate spends: KAR + 30% cold buffer

Every spend through the control plane:

- **KAR** — allowlist, NFC cosign, agent spend vault targets  
- **30% cold buffer** — no single hot path drains the full idle stack  

**Result:** Idle USDC path is **ungameable** (no rogue agent / external pressure drain).

### 3 — Route fills: Conflux · AnchorX · SBI

Convert idle eUSD into **real USDC** via **regulated external rails**, not HOT-only recycling:

| Rail | Role |
|--|--|
| **Conflux** | RMB / CN connection |
| **AnchorX** | AxCNH |
| **SBI** | Japan regulated |

**Result:** Idle moves from **Kingdom paper optics** → **external USDC** in credit / landing.

---

## Engineering map (what fires when)

| Job | Path | Block today |
|--|--|--|
| **Uni eUSD/USDC depth** | `CrownPoolEngineer.seedFromUsdc` after **Morpho borrow** on HOT RSS coll (loan ≠ sell) | PARK **idle $0** — borrow reverts until liquidity in book |
| **yRSS withdraw / flash dealloc** | **STOP** — closed loop, no net USDC | 100% util |
| **Macro idle → USDC** | Tweak **3** fills → credit → draw / seed | Counterparty routing, not more flash |

```
CONSTRUCT=elite · live · ZK-gated · tranche-locked · CN wired
GAP=idle eUSD → external USDC
FIX=attest idle · KAR+30% cold · Conflux/AnchorX/SBI fills
POOL=borrow+seedFromUsdc when market idle ≥ ask · NO yRSS flash · NO RSS sell
```

---

## Scribe one-liner

> The construct is elite. The gap is idle USDC. The fix is three tweaks: **attest, gate, route.** Do that, and the stack is **ungameable**.
