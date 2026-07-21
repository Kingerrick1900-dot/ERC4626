# Spoils of War — war chest LIVE

**RESTORED** on `cursor/engineer-create-positions-efa1` (source + fires + scoreboard).  
On-chain engines below were already LIVE — this brings the repo kit back.

**Doctrine:** RSS out → USDC back. No begging. Elite playbook, Kingdom execution.

**War chest fire:** `FireWarChest.s.sol` · **Harvest fire:** `FireHarvestSpoils.s.sol`  
**Create stack (shelf):** `ENGINEER-CREATE-GO.md` — CDP / bribe / King book

---

## LIVE addresses (Base)

| Engine | Address | Stock / state |
|--------|---------|---------------|
| **Spoils router** | `0xF7B90BE47fa67100dF91ea6E52C588063d1E5bE0` | sweep → Landing |
| **Dutch bond** | `0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81` | 500k RSS · $0.94→$0.99 · 7d |
| **First Whale** | `0xC33256BCb972db576d116D5Ca5B56A8B457337E8` | 50k RSS rebate · ≥$500k threshold |
| **Desk @ $1** | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` | 700k RSS |
| **Bond @ $0.97** | `0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039` | 520k RSS |
| **yRSS fee recipient** | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` | 10% performance fee |

**Deploy txs (war chest):**
- Spoils router: `0x210b7b1e7f12435122b025163fb5c74c2f54c473edcd662e32cf1e18fe2f6fe2`
- Dutch bond: `0xa5b06267c7901eaa69b298d442f595368e0df2ebd4b4dba2e61812c2dbc9cfcd`
- First Whale: `0xe9ea0045261c806226e46458e7c2d726e66c9926526c259ee46404189318cb2c`

---

## IN engines (deployed / armed)

| Engine | Role | RSS stocked |
|--------|------|-------------|
| **Desk @ $1** | Peg OTC | 700k |
| **Bond @ $0.97** | Fixed discount | 520k |
| **Dutch bond** | Price **rises** daily — buy early or pay more | 500k |
| **First Whale** | 500k USDC into yRSS → **50k RSS rebate** | 50k rebate |
| **Spoils router** | Sweep any token → Landing | — |
| **Capture daemons** | `capture-all-idle.sh` · `opportunity-capture.sh` | armed |
| **BRETT rail** | Buy · post · borrow → Landing | live |
| **yRSS fee** | 10% → **Landing** | meter live |

**Total RSS armed for sale:** 1.72M (desk + bond + dutch) + 50k whale rebate = **1.77M RSS** outbound inventory.

---

## Dutch bond (urgency)

- **Floor:** $0.94/RSS (start)
- **Ceiling:** $0.99/RSS (end of window)
- **Duration:** 7 days
- **Fill:** `bondWithUsdc(amount)` — USDC straight to Landing
- **Now:** call `currentPrice()` on contract — early = deeper discount

---

## First Whale (engineered depositor)

1. Depositor puts **≥ $500k USDC** into yRSS via whale contract  
2. Claims **50k RSS rebate** once  
3. Kingdom **captures idle** → borrow → Landing  

Someone else's USDC creates the book. RSS pays the rebate.

---

## Harvest & capture (scribe ops)

```bash
# Return ledger
bash script/return-path-status.sh

# Point fees + sweep hot dust → Landing (already fired)
KING_OK=1 FIRE_HARVEST=1 forge script script/FireHarvestSpoils.s.sol --rpc-url $BASE_RPC --broadcast

# When RSS idle >= $500k
AUTO_FIRE=1 KING_GO=1 bash script/capture-all-idle.sh
```

---

## Ignition (when hot has USDC seed)

```bash
KING_OK=1 FIRE_IGNITION=1 SEED_USDC=25000000000 forge script script/FireAeroIgnition.s.sol ...
```

Creates RSS/USDC Aero pool + RSS-heavy LP — USDC accumulates on swaps.

---

## Outbound

Full copy block: `OUTBOUND-DUAL-RAIL.md`

**Spoils = Landing USDC + desk/bond/dutch raised + capture borrows + yRSS fees.**

Scoreboard: `bash script/return-path-status.sh` · `bash script/plays-status.sh`
