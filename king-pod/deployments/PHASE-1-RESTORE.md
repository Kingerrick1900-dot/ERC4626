# Phase 1 — Restore King self-seed fortress

**Goal:** Same position as before — RSS collateral posted, ~$9M Morpho debt, ~$9M yRSS war chest, oracle moat live.

**Access / FEED = Phase 2.** Do not mix.

---

## End state (target)

| Check | Target |
|-------|--------|
| Hot RSS collateral (Morpho) | ~18.5M |
| Hot USDC debt | ~$9M |
| yRSS totalAssets | ~$9M |
| Hot yRSS shares | ~$9M assets |
| Hot wallet USDC | ~$1 floor |
| LTV | ~48.6% (under 70%) |
| HF vs 77% LLTV | ~1.58 |
| yRSS supplyQueue[0] | RSS market |

---

## Contracts

| Piece | Address / file |
|-------|----------------|
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Morpho Blue | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| RSS | `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| RSS/USDC market | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| RSS oracle ($1) | `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` |
| Seeder | `src/CrownSelfSeedNine.sol` |
| Script | `script/FireSelfSeedNine.s.sol` |

---

## Execution (King GO)

### Step 1 — Prep (deploy + authorize + RSS-first queue)

```bash
cd king-pod
KING_GO=1 FIRE=0 \
  forge script script/FireSelfSeedNine.s.sol:FireSelfSeedNine \
  --rpc-url $RPC --broadcast --slow -vvvv
```

Save printed `seeder` address → `SEEDER=0x…`

### Step 2 — Fire self-seed (one atomic tx)

```bash
KING_GO=1 FIRE=1 BORROW_USDC=9000000000000 SEEDER=<from step 1> \
  forge script script/FireSelfSeedNine.s.sol:FireSelfSeedNine \
  --rpc-url $RPC --broadcast --slow --gas-estimate-multiplier 200 -vvvv
```

**What the tx does:**
1. Set yRSS queue RSS-first (if needed)
2. Flash $9M USDC from Morpho
3. Deposit into yRSS → seeds RSS/USDC idle
4. Post hot RSS as Morpho collateral
5. Borrow $9M against RSS → repay flash
6. King holds yRSS shares + Morpho debt

No Gauntlet. No Steakhouse. No King wallet USDC buffer.

### Step 3 — Verify

```bash
cast call 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb \
  "position(bytes32,address)(uint256,uint128,uint128)" \
  0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794 \
  0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url $RPC

cast call 0xF80C0529bD94C773844E459853CD91B9263dD525 \
  "totalAssets()(uint256)" --rpc-url $RPC
```

---

## Gates

| Env | Required |
|-----|----------|
| `KING_GO=1` | Always for broadcast |
| `FIRE=0` | Prep only |
| `FIRE=1` | Execute selfSeed |
| `BORROW_USDC` | Default $9M; min enforced in contract $1M |
| `SEEDER` | Reuse after prep |

Script refuses fire if Morpho RSS position already open.

---

## Phase 2 (later)

Vault V2 `forceDeallocate` / in-kind exit to Landing — separate tx after fortress is live.
