# War Elephant — Full Battle Plan

**Status: ARMED. No attack until King says go.**

## Objective

Take a **$9M loan against King RSS**, seed **live Vault V2** (forceDeallocate proven), then on order **FEED** liquid USDC to cold landing Cake.

| Role | Address |
|------|---------|
| Hot (daily / signer) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing (cold Cake) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Vault V2 | `0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9` |
| Adapter | `0x3088de5b1629C518382a55e307b1bD45f3BFEE8c` |
| RSS / USDC market | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |

## Why this works now (not before)

- **Before:** $9M sat in V1 yRSS at ~100% util — **trapped**.
- **Now:** V2 + live-proven `forceDeallocate` → King **can access and move** vault USDC even at full util.
- Still a **loan against King RSS** (self-lend / recycle). Not outside capital. Control problem is solved.

## Phases

### Phase 0 — PREP (scribe does now / anytime)

```bash
cd king-pod
PRIVATE_KEY=<hot> forge script script/FireWarElephant.s.sol \
  --rpc-url $RPC --broadcast -vvvv
```

**Does:** deploy `CrownSelfSeedV2`, Morpho authorize, RSS approve.  
**Does NOT:** borrow, deposit, or lock RSS.

Gates off by default.

### Phase 1 — ATTACK (King go only)

```bash
KING_GO=1 FIRE_ATTACK=1 BORROW_USDC=9000000000000 PRIVATE_KEY=<hot> \
  SEEDER=<from prep log> \
  forge script script/FireWarElephant.s.sol --rpc-url $RPC --broadcast -vvvv
```

**Atomic flow:**
1. Post ~18.5M RSS as Morpho collateral (on hot)
2. Flash $9M USDC
3. Deposit $9M → Vault V2 (shares to hot; auto-allocates to RSS market)
4. Borrow $9M against RSS → repay flash

**End state after ATTACK:**
- Hot: Vault V2 shares ≈ $9M (accessible)
- Hot: Morpho debt ≈ $9M, RSS locked
- Wallet liquid USDC ≈ still dust
- Soft LTV 70% vs ~18.5M RSS @ $1 → $9M OK

### Phase 2 — FEED (King go only)

```bash
KING_GO=1 FIRE_FEED=1 PRIVATE_KEY=<hot> \
  forge script script/FireFeedWarElephant.s.sol --rpc-url $RPC --broadcast -vvvv
```

**Flow:** penalty → 0 briefly → flash IKR → `forceDeallocate` → withdraw **USDC to landing** → restore penalty 1%.

**End state after FEED:**
- Landing Cake: ≈ **$9M USDC** (liquid, cold)
- Hot: vault shares ≈ 0
- Morpho debt + RSS **still open** until a later unwind (repay → free RSS)

FEED = control of the dollars. Unwind RSS = separate King order.

## Gates (hard)

| Env | Required to |
|-----|-------------|
| *(none)* | PREP only |
| `KING_GO=1` + `FIRE_ATTACK=1` | ATTACK |
| `KING_GO=1` + `FIRE_FEED=1` | FEED |

No gate → no loan. Scribe will not fire without these.

## Pre-flight checklist (before King go)

- [ ] Hot has enough **ETH gas** (recommend ≥ 0.02 ETH on Base; currently ~0.005 — **top up before attack**)
- [ ] Hot holds ~18.5M RSS
- [ ] Vault owner = landing, curator = hot, penalty = 1%
- [ ] PREP done; `SEEDER` address recorded
- [ ] Landing Cake ready to receive (no dapp connects)
- [ ] Old Cake still abandoned (key was exposed)
- [ ] King confirms size `$9M` (or set `BORROW_USDC`)

## After success — discipline

1. Landing stays cold — receive only, never connect dapps.
2. Do not paste landing seed anywhere.
3. Hot remains ops only.
4. RSS unlock only when King orders repay/unwind.
5. This is still self-lend economics — access ≠ outside TVL.

## Scripts

| File | Role |
|------|------|
| `src/CrownSelfSeedV2.sol` | Attack seeder → live V2 |
| `script/FireWarElephant.s.sol` | Prep + gated attack |
| `script/FireFeedWarElephant.s.sol` | Gated feed to landing |
| `src/CrownLiveExitTest.sol` | Prior live exit proof ($100) |

## King one-liners

```text
PREP:   (no env) FireWarElephant --broadcast
ATTACK: KING_GO=1 FIRE_ATTACK=1 FireWarElephant --broadcast
FEED:   KING_GO=1 FIRE_FEED=1   FireFeedWarElephant --broadcast
```

**War elephant is ready. On King’s go only.**
