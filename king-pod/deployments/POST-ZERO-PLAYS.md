# Post-zero engineered plays — no thumb-twiddling

**Morpho debt: ZERO** (tx `0x453b51c6511266d274d257e62c1d00d83f6389d50cdeccb2806aeaf9245de635`).  
**Hot inventory:** ~**17.8M RSS** free. **Desk:** **700k @ $1** live. **yRSS TVL:** **$0** (redeemed during zero — re-arm when USDC depth returns).

Scoreboard: `script/plays-status.sh`

---

## Posture

| Duck | Whale |
|------|-------|
| Wait for Gauntlet maxIn | **Sell / bond RSS** — USDC is commerce |
| Armed coll with $0 idle | **Arm credit line after USDC faces the book** |
| Twitter thumbs | **Engine + packet + sim** |

King controls fire. Scribe builds and sims. **No broadcast without KING_OK.**

---

## Play 1 — Desk @ $1 (LIVE)

| | |
|--|--|
| Contract | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` |
| Helper | `0xeA454FAD0115A8131C3E10bC117A6584f649356b` → `fillPhase1()` |
| Stock | 700k RSS |
| Proceeds | Landing cold |
| Packet | `OPS-COUNTERPARTY-PACKET.md` |

**Action:** send packet. Buyer approves USDC → fills. No protocol permission needed.

---

## Play 2 — Bond @ discount (LIVE)

Olympus-class: sell RSS **below $1 oracle** for urgency. USDC → Landing.

| | |
|--|--|
| Contract | **`0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039`** |
| Fire | `FireRssBond.s.sol` (fired) |
| Stock | **520k RSS @ $0.97** |
| Phase 1 meter | $500k USDC |
| Packet | `BOND-COUNTERPARTY-PACKET.md` |

**Why two rails:** Desk = peg. Bond = **discount = act today**.

```bash
KING_OK=1 FIRE_BOND=0 forge script script/FireRssBond.s.sol --rpc-url $BASE_RPC
```

---

## Play 3 — Credit line re-arm (SHELF · after inflow)

Post RSS collateral → borrow capacity when Morpho idle exists. **Not before idle.**

| | |
|--|--|
| Fire | `FireArmCreditLine.s.sol` |
| Default post | 1M RSS → ~$700k soft capacity @ 70% |

Zero-debt fire cleared old post. Re-arm is **Play 3 after Play 1/2 puts USDC in the market** (buyer supply or yRSS deposit).

---

## Play 4 — yRSS re-seed + fee meter (SHELF)

10% performance fee live on contract. TVL at $0 until USDC returns.

After Landing peel / bond raise: `DepositYrss.s.sol` · `FireYrssFeeGov.s.sol` · PA already capped ~$700k on RSS + BRETT books.

---

## Play 5 — BRETT rail — **LIVE (finished)**

Market seeded + **yRSS USDC on BRETT book** + **King BRETT collateral posted** + borrow path proven.  
See `BRETT-FINISHED.md`. Re-fire `FireFinishBrett.s.sol` to upsize when more ETH/USDC on hot.

---

## Play 6 — War chest (Dutch + First Whale + Spoils) — **LIVE**

Spoils engines above the call of duty. RSS pays; USDC returns to Landing.

| | |
|--|--|
| Fire | `FireWarChest.s.sol` (fired) |
| Dutch | **`0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81`** — 500k RSS, $0.94→$0.99 over 7d |
| First Whale | **`0xC33256BCb972db576d116D5Ca5B56A8B457337E8`** — 50k RSS rebate for ≥$500k yRSS deposit |
| Spoils router | **`0xF7B90BE47fa67100dF91ea6E52C588063d1E5bE0`** — King sweep → Landing |
| Harvest | `FireHarvestSpoils.s.sol` — yRSS fee recipient → Landing (fired) |
| Packet | `SPOILS-OF-WAR.md` · `OUTBOUND-DUAL-RAIL.md` |

---

## Scribe queue (building · not broadcasting)

1. Bond buyer packet (mirror desk packet, discount terms)
2. Aerodrome Ignition plan — RSS incentives for USDC LPs (needs pool + King OK)
3. Re-arm + borrow sim when idle ≥ size (`FireCashLeg500.s.sol` dry-run)
4. `plays-status.sh` on every check-in

**Engineering ≠ waiting.** Waiting is only for **counterparty signature** or **King FIRE**.
