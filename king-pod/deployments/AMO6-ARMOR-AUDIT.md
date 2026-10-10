# AMO 6 Armor — Audit Package

**Status:** Built · ready for audit · **not fired** (`FIRE_AMO6=1` required)  
**Law:** No AMO 1 external legs until this package is green on-chain.

---

## Contracts (this repo)

| File | Role |
|--|--|
| [`src/CrownCircuitBreaker.sol`](../src/CrownCircuitBreaker.sol) | Real kill switch — eUSD < $0.98 **or** yRSS drop > 5% → pause AMOs → route to Aave safe venue. Replaces HuntRouter theater. |
| [`src/ColdBufferLaw.sol`](../src/ColdBufferLaw.sol) | Abstract · `minBufferBps = 3000` · every reward path `_routeRewards` → 30% `ColdBuffer.fund` |
| [`src/MintGate.sol`](../src/MintGate.sol) | `canMint()` surface · ships `unlocked = 0`, `canMint = false` · King-only unlock |
| [`src/CrownColdBuffer.sol`](../src/CrownColdBuffer.sol) | Live buffer `0xBb3c…5521` — deploy script sets `minBufferBps = 3000` if still 0 |

Deploy: `script/DeployAmo6Armor.s.sol` · Tests: `test/Amo6Armor.t.sol`

---

## Checklist (post-deploy acceptance)

| # | Item | Acceptance |
|--:|--|--|
| 1 | Quantum registry | `CrownPqRegistry` `keyCount > 0` (already live `0xC92b…DC95`) |
| 2 | ZK NAV ×3 | Attest code on Base/Poly/Scroll |
| 3 | `bordersSecure` ×3 | `true` |
| 4 | ColdBuffer 30% | Live `minBufferBps == 3000` **and** AMOs inherit `ColdBufferLaw` |
| 5 | Kill switch armed | `CrownCircuitBreaker.armed == true` · `tripped == false` · baseline set · ≥1 AMO registered |
| 6 | Mint gate locked | `MintGate.canMint() == false` · `unlocked == 0` |
| 7 | Publish epoch + hashes | Scoreboard doc updated with attest epochs + breaker/gate addresses |

---

## Hard gates

- No AMO 1 Ocean external-leg seed until rows 4–6 green on-chain.  
- AxCNH / China corridor: held for King signature.  
- Tranches: `unlocked = 0` until King `unlockTranche`.  
- `CrownFlashBleed`: **reference-only** — not wired, not active.

---

## Already live (pre-armor)

| Piece | Address / value |
|--|--|
| ZkAttest Base | `0xe3Be…14E7` · borders true · epoch 15 |
| ZkAttest Polygon | `0x00cA…7211` · true · 6 |
| ZkAttest Scroll | `0x2ab1…a257` · true · 8 |
| PqRegistry | `0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95` · keyCount 4 |
| ColdBuffer | `0xBb3c14bBacD639797cB5c537fde370d1b7195521` |
| A+B Sweep / Convert | see `FIRE-3M-AB.md` |

---

## Fire (King / KAR only)

```bash
FIRE_AMO6=1 HOT_KEY=$HOT_KEY \
  forge script script/DeployAmo6Armor.s.sol:DeployAmo6Armor \
  --rpc-url $BASE_RPC_URL --broadcast --slow --with-gas-price 6000000
```

Then: `registerAMO` for each live AMO · publish addresses + epoch to scoreboard · re-probe checklist.
