# Next Plan — Engineer the Book (No Waiting)

Idle on ELE/USDC is **0 right now** → `FIRE_BORROW` does not fire.  
There is no “when idle” lane. Idle is something we **build**, not something we sit on.

---

## Thoughts (Chief)

The fortress already works as credit machinery:

- Morpho: **40.1M Elepan posted** · **~$14M borrowed** · **~$16.9M more room**
- CDP: **25.2M posted** · **13M eUSD** on Landing · more mint + withdraw ready
- yELE: **~$14M** · top-tier Base Morpho USDC vault by size
- ZK: **$1M proven** · draw rail aimed at Landing

What’s wrong with the old posture: treating foreign idle as weather.  
That’s not a position. A position is a book foreign USDC can enter and King can draw.

Self-seed filled the vault and the borrow in one stroke. That made TVL. It also locked redeem (`maxWithdraw=0`) because King is both supply and borrow. The next move is to **reshape the book so liquidity can sit idle against collateral that is already posted** — then draw.

---

## Plan — three engineered moves

### Move 1 — Surface now (King GO)
Pull posted Elepan that is already free inside the loans. Builds liquid inventory for Move 2/3.

| Fire | Size (live) |
|--|--|
| `FIRE_MORPHO_PULL=1` | **~20.1M Elepan** to hot · $14M borrow stays |
| `FIRE_CDP=1 MODE=both` | **~5.05M Elepan** + **~3.26M eUSD** → Landing |

After Move 1: hot Elepan ≈ **34.6M free + 20.1M pull + 5.05M CDP ≈ 60M** liquid surface.

```bash
KING_GO=1 FIRE_MORPHO_PULL=1 forge script script/FireMorphoPullElepan.s.sol:FireMorphoPullElepan --rpc-url $BASE_RPC --broadcast --slow
KING_GO=1 FIRE_CDP=1 MODE=both forge script script/FireCdpSurface.s.sol:FireCdpSurface --rpc-url $BASE_RPC --broadcast --slow
```

### Move 2 — Open the Morpho door (King GO + curator packet)
Engineer **inbound** USDC into ELE/USDC — not hope.

1. Keep Elepan as **collateral-only** on Morpho (already true on hot).  
2. Ship curator packet today to Gauntlet / Steakhouse / Moonwell: set PA `flowCaps` **maxIn ≥ $700k–$5M** on market `0xa4ec5271…da53fc`.  
3. On first non-zero maxIn: PA `reallocateTo` + `FIRE_BORROW` in one shot → Landing.

Packet targets (Base USDC vaults with depth):

| Vault | TVL class |
|--|--|
| Gauntlet USDC Prime `0xeE8F…b61` | ~$400M+ |
| Steakhouse Prime USDC `0xBEEF…b2` | ~$200M+ |
| Steakhouse USDC `0xbeeF…183` | ~$180M+ |
| Moonwell Flagship USDC `0xc125…A2Ca` | ~$9M |

This is outbound engineering (packet + caps ask), not a calendar wait.

### Move 3 — ZK fill rail (King names the supplier)
Gate is proven **$1M** · LLTV 70% · Landing receiver live.  
King names who `supply`s USDC into `0xc415…d936`. On supply: draw → Landing. Same-day cash rail.

---

## Scoreboard that counts

| Meter | Direction |
|--|--|
| Hot liquid Elepan | ↑ after Move 1 |
| Landing USDC | ↑ after Move 2 or 3 fill |
| ELE market idle | ↑ because we opened a door (PA/ZK/supplier) |
| Morpho headroom used | ↑ on draw |

---

## Kill rule

Do not write another step that starts with “once idle appears.”  
If idle is **> 0**, fire borrow same block. If idle is **0**, execute Move 1 / 2 / 3.

**Awaiting King GO on Move 1 flags** (`FIRE_MORPHO_PULL` / `FIRE_CDP`) and name on Move 2/3 counterparty.
