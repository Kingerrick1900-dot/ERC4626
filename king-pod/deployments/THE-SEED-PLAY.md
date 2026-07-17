# THE SEED — where $100k–$700k actually is

## Scanned King contracts (live)
- King hot USDC: **$0**
- KingVault USDC: **$4.87**
- yRSS-USDC vault TVL: **$0**
- RSS Morpho market liquidity: **$0**
- King RSS wallet: **~18.49M** (collateral, not cash)
- V1 / V2 pods: **$0 USDC** recoverable
- Fleet signer: **dust ETH only**

**There is no seed inside King's contracts.** You were right to call that out.

---

## Where the seed actually lives (not King's wallet)

### Seed source A — Morpho vault TVL on Base (~$800M+ USDC)

| Vault | TVL (approx) | PA fee |
|-------|----------------|--------|
| Gauntlet USDC Prime `0xeE8F…4b61` | ~$427M | 0 |
| Steakhouse Prime `0xBEEF…83b2` | ~$230M | 0 |
| Steakhouse USDC `0xbeeF…8183` | ~$191M | 0 |

This is real USDC. It sits in WETH/cbBTC/USDe markets today. **None of it flows to RSS market yet** — Morpho API: `reallocatableLiquidityAssets = 0`, `publicAllocatorSharedLiquidity = []`, zero vaults list RSS.

**The play:** get RSS/USDC market (`0x40ac…b794`) **enabled with flow caps** on a fat vault's Public Allocator. Then one bundled tx:

`reallocateTo` (pull USDC from Gauntlet/Steakhouse book) → `supplyCollateral` (RSS) → `borrow` (USDC → KingVault).

King supplies **RSS only**. The **$100k–$700k is their depositors' USDC**, reallocated in the borrow tx. Not King's wire. Not a token sale.

**Worker ships:** curator listing packet (market params, oracle `0x284E…`, 77% LLTV, cap, risk memo) + Morpho SDK bundler calldata ready to fire when a curator sets `maxIn`.

**Gate:** Steakhouse / Gauntlet curator must accept RSS market on their vault (timelock). Worker submits. Cannot force on-chain without them.

---

### Seed source B — yRSS-USDC vault depositors

Vault **already live:** `0xF80C0529bD94C773844E459853CD91B9263dD525`  
10% perf fee → King. $15k cap on RSS market allocation.

**The play:** USDC deposits into yRSS → vault allocates to RSS Morpho market → King borrows against RSS → KingVault.

**Gate:** depositors. Same money problem unless Source A fills yRSS from outside.

---

### Seed source C — private seat wire (Kingdom fund plan)

One permissioned allocator wires USDC to King hot → seed desk + Morpho + elite close → vault.

**Gate:** human with USDC. Agent cannot produce the wire.

---

## What is NOT seed

- Morpho global flash float (~$192M on contract) — same-tx repay only
- RSS tokens — collateral, not USDC
- Arb / rescue / fire-duty — don't create $100k–$700k

---

## The play (ranked)

1. **Unlock Source A** — submit RSS market to Gauntlet + Steakhouse curator flow caps. Fire reallocate+borrow bundle when `maxIn > 0`. King posts RSS. Vault takes $B USDC. **This is the only path that doesn't require King to write a check.**

2. **Arm bundler now** — Morpho SDK `supplyCollateralBorrow` + `targetReallocations` against Steakhouse High Yield / Gauntlet Prime withdrawal markets. Parked until Source A opens.

3. **Source B + C** — parallel only if A stalls.

---

## Honest line

Agent cannot mint $100k–$700k. Neither can King from empty contracts. The seed is **in Morpho vault TVL on Base** — locked until a curator opens the RSS market door. Worker opens the door. King fires when it's open.
