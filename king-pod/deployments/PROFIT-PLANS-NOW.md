# KINGDOM PROFIT PLANS — NO “WHEN MONEY ARRIVES”

Standard: USDC to KingVault `0xA1aFcb46a64C9173519180458C1cF302179c832a`.  
Kill any plan whose first step is “wait for curator / depositor.”

---

## PLAN A — STRIKE (primary cash)

**Job:** Liquidate HF&lt;1 Morpho positions on Base → keep bonus → vault.

1. Scan Base USDC (and WETH) Morpho markets for HF&lt;1 with liquid collateral (cbBTC, WETH, LSTs — skip zero-price junk).
2. Size: flash Morpho USDC → `liquidate` → swap seized asset → repay flash → send profit to KingVault.
3. Route flash through CrownFlashRouter (30 bps already → vault) when it doesn’t kill edge.
4. Run continuous: fleet `0xcbD8…` gas-funded; fire every profitable hit same block if possible.
5. Partial liqs first when full close eats bonus.

**Profit source:** Protocol liquidation incentive (Morpho design).  
**Needs from King:** Gas only (fleet key live).  
**Fire script:** Strike desk + Morpho liquidation SDK path.

---

## PLAN B — FLASH ARB (secondary cash)

**Job:** Morpho flash USDC → 2-leg DEX misprice → repay → vault.

1. Quote Base routes (Aerodrome / UniV3) where buy-low/sell-high &gt; flash fee + router 30 bps + gas cushion.
2. `CrownFlashArb` / router: only fire if sim profit &gt; floor (start $5, raise).
3. Treasury = KingVault (already set).
4. Cron every block or every N seconds on top pools (WETH/USDC, cbBTC/USDC, AERO pairs).

**Profit source:** DEX dislocation.  
**Needs:** Gas. No depositor.  
**Kill rule:** No fire on hope; sim must clear floor.

---

## PLAN C — CROSS-FLASH SPOIL (oracle + RSS power)

**Job:** Use live RSS collateral / oracle book to extract USDC *now*, not list to curators.

### C1 — Headroom borrow when ANY idle exists
- Position: ~18.5M RSS @ $1, debt ~$9.25M, HF~1.54 → ~$5M paper headroom.
- Watch Morpho `liquidityAssets` on RSS market. The instant idle &gt; 0 (anyone supplies, interest dust, PA trickle): `CrownSpoilFire` borrow → KingVault.
- No curator meeting. Bot. Same block if possible.

### C2 — Cross-market flash loops (other assets)
- Flash USDC from Morpho (global float, not our market).
- Use only if a closed loop ends with leftover USDC after repay:
  - Liq loop (Plan A)
  - Arb loop (Plan B)
  - Collateral swap loop only if RSS or other holding has a real bid (DEX/desk with USDC inventory)
- Do **not** open another circular self-lend and call it profit.

### C3 — Unwind-slice to vault (only if King orders book shrink)
- Flash → repay $X debt → withdraw $X supply → send USDC to vault → repay flash from vault? Net zero.
- Real version: unwind $X to desk, King wires external USDC for flash repay, vault keeps $X — **only if King has external USDC**. Otherwise skip.

---

## PLAN D — FEE SKIM (always on)

**Job:** Every flash/liq/volume path pays vault without asking.

1. CrownFlashRouter fee 30 bps → KingVault (live).
2. yRSS performance fee 10% → KingVault (live).
3. Force accrue + skim on any yRSS TVL the moment it exists (cron).
4. Publish router ABI only to keepers who pay the fee.

**Profit source:** Flow tax. Works when Strike/arb volume runs.

---

## PLAN E — DESK / SALE FILL (only with real bids)

**Job:** Turn RSS inventory into USDC when a buyer has USDC.

1. Desk + sale already @ $1 (match oracle).
2. Fill only against external USDC — no self-deal theater.
3. OTC: Strike seized assets ↔ desk RSS if it improves vault USDC.

---

## PLAN F — KILL LIST (stop building these as “profit”)

- Curator listing as the profit engine  
- “When PA maxIn opens” as the main story  
- Bigger circular PoD book as if it fills vault  
- Flash NAV / depositor drain  
- Public RSS dump as growth  

Curator packet stays as **optional politics**, not the machine.

---

## EXECUTE ORDER (tonight / next fire)

| Priority | Plan | Action |
|--|--|--|
| 1 | A Strike | Stand up live HF&lt;1 scanner + liquidate → vault |
| 2 | B Arb | Sim top Base USDC routes; fire if &gt; floor |
| 3 | C1 Spoil bot | Poll RSS market idle; borrow headroom → vault |
| 4 | D Fees | Keep router/yRSS pointed at vault; skim cron |
| 5 | E Desk | Only on real USDC bids |

**Success metric:** KingVault USDC balance up. Not TVL theater. Not util screenshots.
