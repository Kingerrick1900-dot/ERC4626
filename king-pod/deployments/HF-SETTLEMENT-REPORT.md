# HF + Settlement Report — post first fat flash

## Oracle (unchanged doctrine)

| Feed | Reading |
|------|---------|
| RSS | Fixed **$1** (King-owned) |
| WETH (via Uni TWAP) | ~**$1933** |
| cbBTC (via Uni TWAP) | ~**$66380** |

No aggressive oracle changes. Monitor depeg vs CEX.

## HF after first flash

| | After seed (LLTV-tight) | After collateral top-up |
|--|--------------------------|-------------------------|
| RSS/WETH HF_raw | **1.32** (BELOW 1.55) | **1.56** |
| RSS/cbBTC HF_raw | **1.32** (BELOW 1.55) | **1.56** |

Top-up txs:
- WETH coll: `0x5dd3a77fd7b28e58ad14761af67b23ab38a02aa76d1f0c5068a1a85d06af96fe`
- cbBTC coll: `0xfe92c92a23e6e3769d5ac98cde46d7077b379f1e40ed3dcf3d1f5e3b185c924e`

Guard locked in `CrownFatFlashSeed` `0x38bF10f1b62282F08f9fC97E2DB116DD2cBbf2F6`: revert if post-action HF_raw < **1.55**. Alert event if < **1.60**.  
Monitor: `script/hf_monitor_rss_weth_cbbtc.sh`

Still in watch band (1.55–1.60). Next tranches size RSS for HF ≥1.60 if King wants clear of alert.

## kUSD / hot / usable cash

| Seat | kUSD | USDC |
|------|------|------|
| Hot | **0** | **0** |
| ZkAdvance | **699,994** | **0** |
| PSM | **0** | **0** |
| Landing | **0** | **~$1.04** |
| Aero kUSD/USDC | ~6e6 units | **~$6** |

**Conversion blocker:** 700k kUSD is parked in ZkAdvance. PSM empty. Aero tip is dust (~$6). Cannot swap 700k→USDC on-chain today without a USDC buyer into PSM/Credit/desk.

## Top bill

**Unset.** Docs still: King sets `BILL_USDC` for first wire. No number on disk.

## Settlement priority (not more builds)

1. Force USDC into PSM / Credit / desk fill (≥$500k band)
2. Sweep Landing
3. King names bill → off-ramp slice
4. Only then scale WETH/cbBTC flash tranches under HF≥1.55
