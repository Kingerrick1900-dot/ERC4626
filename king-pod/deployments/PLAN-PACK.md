# PLAN PACK — use what’s built

## Plan 1: ACTIVATE yRSS-USDC (already live, $0 TVL)

**Vault:** `0xF80C0529bD94C773844E459853CD91B9263dD525`  
**Symbol:** yRSS-USDC · King curator · 10% perf fee → King hot  
**RSS market cap:** $15k USDC · supply queue = King RSS/USDC market  

**Job:** USDC in vault → allocated to RSS Morpho market → loan pile exists → post RSS → borrow USDC → KingVault. Loans + tokens. Not arb. Not rescue.

**Worker ships:** `activate-yvault.s.sol` — deposit, reallocate/supply to market, supplyCollateral, borrow(receiver=KingVault).  
**King:** one sign when script is ready.

---

## Plan 2: REFINANCE DOOR (your Morpho SDK path)

**Job:** Pull USDC from fat Base vaults (Steakhouse, Gauntlet, etc.) into King RSS market in the same tx as collateral + borrow.

**Morpho pattern:** `supplyCollateralBorrow` + `targetReallocations` (PublicAllocator `reallocateTo` prepended).

**Blocker today:** Morpho API shows **zero** PA paths into RSS market. Door is closed until a vault curator allows RSS market in flow.

**Worker ships:**
- Bundler calldata builder for RSS market + reallocate from top USDC vaults
- Curator listing packet (Steakhouse / Gauntlet / Moonwell) — market params, oracle, cap, risk memo — ready to send

**When door opens:** one bundled tx — post RSS, reallocate USDC in, borrow to KingVault.

---

## Plan 3: LOANS + HOLD (direct Morpho)

**When:** RSS market `liquidityAssets` > 0 (from Plan 1 deposit or Plan 2 reallocate).

**Fire:** post ~18.5M RSS collateral → borrow up to LLTV (~$712k ceiling, size = liquidity) → **KingVault** → hold debt.

**Worker ships:** `FirePowerBorrow.s.sol` — no elite-close, no debt zeroing.

---

## Plan 4: INBOUND LOADER (live, parked)

**`fire-duty.sh` + `CrownEliteFlashClose` `0x39D8…1a41` · railBps=0**

Any USDC hitting King hot → auto seed desk → elite flash → vault. Relocate rail. Worker keeps armed.

---

## Plan 5: TRUST LISTING (brand pack exists)

**RSS** `0x7a305D07B537359cf468eAea9bb176E5308bC337` — logo + info.json ready on `rss-verify-brand` branch.

**Worker:** open Trust Wallet assets PR. Private discoverability for yRSS depositors. Not a public token sale.

---

## Execution order

1. Plan 1 activate script (vault already deployed)  
2. Plan 2 refinance packet + bundler (parallel)  
3. Plan 3 fire borrow when liquidity > 0  
4. Plan 4 loader stays on  
5. Plan 5 listing PR  

## Killed (do not loop)

- Crown arb bot  
- Rescue HF lottery  
- New MetaMorpho deploy (vault exists)  
- Fourteen-day calendars  
- “King enrolls / finds / calls”

Greenlight = worker builds Plan 1 + 2 scripts first.
