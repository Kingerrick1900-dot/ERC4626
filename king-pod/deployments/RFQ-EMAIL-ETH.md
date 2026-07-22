# RFQ Email — Ready to Send (corrected)

**To:** OTC Desk (Wintermute / FalconX / Kraken Pro)  
**Subject:** RFQ — $700,000 DAI / USDT / ETH (or USDC), settle Ethereum, T+0/T+1

---

Dear OTC Desk,

We request a firm quote:

| | |
|--|--|
| **We sell** | **700,000 RSS** (Base), Fixed \$1 oracle, owner burned |
| **We buy** | **\$700,000** in **DAI, USDT, ETH, or USDC** |
| **Settlement** | **Ethereum mainnet** preferred · T+0 / T+1 |
| **Min size** | \$500,000 |
| **Counterparty** | KE-SOV-001 — Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |

### On-chain fill (Base → ETH), ready now

**Option A — Multi-stable / ETH**  
`CrownMultiStableRail` `0xbC47996a7B34F049DF4701116BA7936F360a7242` (700k RSS stocked)  
- DAI/USDT → `fillStable(token, amt, amt*1e12, 1)`  
- ETH → `fillEth{value}(rssOut)`  
- USDC → Ethereum via CCTP: `fillStable(USDC, amt, amt*1e12, 2)`

**Option B — USDC CCTP only**  
`CrownOtcEthRail` `0x683886A3911323e92A6C764c3331CAC168D0029E` (700k RSS stocked)  
`fill(usdcAmt, usdcAmt*1e12, 0, 2)` → native USDC mints on Ethereum to Landing.

**Option C — Ethereum wire**  
Send DAI / USDT / ETH / USDC on Ethereum to Landing `0x5Adc…2357`; we release RSS on Base same day.

### Proofs
- ZK reserves gate: `isProven(0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1) = true`
- PCV + LBP live (protocol-owned seed, 48h 80/20→20/80)
- Morpho Vault V2 curator = King hot; yRSS fee 10% → Landing

Please quote best price for \$700k (or \$500k) and the desk wallet that will call the fill.

Signed,  
**King Errick the Righteous**  
KE-SOV-001

---

## Status (honest)

| Item | Status |
|------|--------|
| RFQ email | ✅ This doc — send it |
| CrownOtcEthRail | ✅ Live + 700k RSS |
| CrownMultiStableRail | ✅ Live + 700k RSS |
| CrownPcvController | ✅ Deployed `0x1B61Da8F…fcb9` |
| CrownRssLbp | ✅ Deployed `0x70dcAb53…7012` |
| PCV seed / LBP live | 🔧 Fund script (`FirePcvFund`) — complete after nonce clear |
| Morpho Vault V2 curator | ✅ Already live |
| Wintermute/FalconX/Kraken fill | ⏳ Desk reply |
